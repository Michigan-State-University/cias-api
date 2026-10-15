# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::BulkImportService do
  subject(:call) { described_class.call(researcher, intervention, payload) }

  # Forced with let! so lazy creation doesn't happen inside an `expect { }.to change(User, :count)`
  # block (the intervention factory creates its own User, which would show up as a spurious delta).
  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user_id: researcher.id) }

  def attrs(email: nil, first_name: 'Alice', last_name: 'Smith')
    { 'first_name' => first_name, 'last_name' => last_name, 'email' => email }.compact
  end

  def entry(attrs_hash: {}, variable_answers: {})
    { 'attributes' => attrs_hash, 'variable_answers' => variable_answers }
  end

  describe 'participants-only import (no RA session)' do
    let(:payload) { [entry(attrs_hash: attrs(email: 'p1@example.test'))] }

    it 'creates a User + PredefinedUserParameter' do
      expect { call }.to change(User, :count).by(1).and change(PredefinedUserParameter, :count).by(1)
    end

    it 'bumps participants_created, leaves RA counters at zero' do
      result = call
      expect(result).to include(total: 1, participants_created: 1, ra_completed: 0, ra_partial: 0, failed: 0)
    end
  end

  context 'with an RA session' do
    let!(:ra_session) { create(:ra_session, intervention: intervention, variable: 's1') }
    let!(:question_group) { create(:question_group, session: ra_session) }

    def single_question(variable:, values:)
      create(:question_single,
             question_group: question_group,
             body: {
               'data' => values.each_with_index.map { |v, i| { 'payload' => "Opt #{i + 1}", 'value' => v } },
               'variable' => { 'name' => variable }
             })
    end

    describe 'all answerable questions answered → auto-finish' do
      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      let(:payload) do
        [entry(
          attrs_hash: attrs(email: 'p1@example.test'),
          variable_answers: { 's1.mood' => '2' }
        )]
      end

      it 'bumps ra_completed' do
        result = call
        expect(result).to include(participants_created: 1, ra_completed: 1, ra_partial: 0, failed: 0)
      end

      it 'marks the user_session finished' do
        call
        user_session = UserSession::ResearchAssistant.find_by(session_id: ra_session.id)
        expect(user_session.finished_at).to be_present
        expect(user_session.fulfilled_by_id).to eq(researcher.id)
        expect(user_session.started).to be true
      end

      it 'sets UserIntervention to in_progress' do
        call
        ui = UserIntervention.find_by(intervention_id: intervention.id)
        # finish triggers update_user_intervention which may promote status
        # further; we only assert it's not stuck in ready_to_start.
        expect(ui.status).not_to eq('ready_to_start')
      end

      it 'creates an Answer with the stripped value and correct body shape' do
        call
        answer = Answer.joins(:user_session).where(user_sessions: { session_id: ra_session.id }).first
        expect(answer).to be_a(Answer::Single)
        expect(answer.decrypted_body['data'].first).to include('var' => 'mood', 'value' => '2')
        expect(answer.draft).to be false
      end
    end

    describe 'partial answers (some answerable questions unanswered)' do
      before do
        single_question(variable: 'mood', values: %w[1 2 3])
        single_question(variable: 'energy', values: %w[1 2 3])
      end

      let(:payload) do
        [entry(
          attrs_hash: attrs(email: 'p1@example.test'),
          variable_answers: { 's1.mood' => '2' } # energy is unanswered
        )]
      end

      it 'bumps ra_partial not ra_completed' do
        result = call
        expect(result).to include(ra_completed: 0, ra_partial: 1, failed: 0)
      end

      it 'does NOT finish the user_session' do
        call
        user_session = UserSession::ResearchAssistant.find_by(session_id: ra_session.id)
        expect(user_session.finished_at).to be_nil
      end
    end

    describe 'mixed batch (some rows with answers, some without)' do
      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      let(:payload) do
        [
          entry(attrs_hash: attrs(email: 'with@example.test'), variable_answers: { 's1.mood' => '1' }),
          entry(attrs_hash: attrs(email: 'without@example.test'))
        ]
      end

      it 'creates both participants; only the answered one produces ra_completed' do
        result = call
        expect(result).to include(participants_created: 2, ra_completed: 1, ra_partial: 0, failed: 0)
      end
    end

    describe 'counter-bump-after-commit (regression guard for validation-log #46)' do
      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      let(:payload) do
        [entry(attrs_hash: attrs(email: 'p1@example.test'), variable_answers: { 's1.mood' => '1' })]
      end

      it 'does not bump participants_created when import_ra_answers raises after create_participant!' do
        allow_any_instance_of(described_class).to receive(:import_ra_answers).and_raise(StandardError, 'boom')
        allow(Sentry).to receive(:capture_exception)

        result = call
        # Transaction rolled back the user + pup; counters must not be bumped
        # for the rolled-back row. Using `User.exists?` not `.where(...).not_to exist`
        # because the codebase's custom `exist` matcher (rails_helper.rb:111-120)
        # calls `.id` on the receiver, which fails on a Relation.
        expect(result).to include(participants_created: 0, ra_completed: 0, ra_partial: 0, failed: 1)
        expect(User.exists?(email: 'p1@example.test')).to be false
      end
    end

    describe 'per-participant StandardError isolation (Sentry captured)' do
      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      let(:payload) do
        [
          entry(attrs_hash: attrs(email: 'ok@example.test'), variable_answers: { 's1.mood' => '1' }),
          entry(attrs_hash: attrs(email: 'bad@example.test'), variable_answers: { 's1.mood' => '1' })
        ]
      end

      it 'captures the error to Sentry and continues processing other rows' do
        call_count = 0
        allow(UserIntervention).to receive(:find_or_create_by!).and_wrap_original do |original, *args|
          call_count += 1
          raise StandardError, 'boom' if call_count == 2

          original.call(*args)
        end

        expect(Sentry).to receive(:capture_exception).with(instance_of(StandardError)).once

        result = call
        expect(result).to include(participants_created: 1, failed: 1)
      end
    end

    describe 'RecordNotUnique does NOT go to Sentry' do
      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      let(:payload) do
        [entry(attrs_hash: attrs(email: 'p1@example.test'), variable_answers: { 's1.mood' => '1' })]
      end

      it 'bumps failed without Sentry.capture_exception' do
        allow_any_instance_of(described_class).to receive(:create_participant!).and_raise(ActiveRecord::RecordNotUnique, 'duplicate')
        expect(Sentry).not_to receive(:capture_exception)

        result = call
        expect(result).to include(failed: 1)
      end
    end

    describe 'whitespace-tolerant key parsing mirrors validator' do
      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      let(:payload) do
        [entry(attrs_hash: attrs(email: 'p1@example.test'), variable_answers: { ' s1.mood ' => ' 2 ' })]
      end

      it 'strips both key halves and the value; creates the answer' do
        call
        answer = Answer.joins(:user_session).where(user_sessions: { session_id: ra_session.id }).first
        expect(answer.decrypted_body['data'].first).to include('var' => 'mood', 'value' => '2')
      end
    end

    describe 'mixed-type RA session (Single + Multiple) with only Singles in CSV' do
      # Multiple is now rejected at the model
      # layer for RA sessions; stub on the instance to simulate legacy data so this regression
      # guard still exercises the auto-finish "partial" path with a non-supported question present.
      before do
        single_question(variable: 'mood', values: %w[1 2 3])
        multiple_q = build(:question_multiple,
                           question_group: question_group,
                           body: { 'data' => [{ 'payload' => 'Opt', 'variable' => { 'name' => 'picks', 'value' => '1' } }] })
        allow(multiple_q).to receive(:type_supported_for_ra_session)
        multiple_q.save!
      end

      let(:payload) do
        [entry(attrs_hash: attrs(email: 'p1@example.test'), variable_answers: { 's1.mood' => '1' })]
      end

      it 'lands in :partial because the Multiple question is unanswered' do
        result = call
        expect(result).to include(ra_completed: 0, ra_partial: 1)
      end
    end

    describe 'health_clinic_id propagation (organisation intervention)' do
      let(:health_clinic) { create(:health_clinic) }
      let(:payload) do
        [entry(
          attrs_hash: attrs(email: 'org@example.test').merge('health_clinic_id' => health_clinic.id),
          variable_answers: { 's1.mood' => '1' }
        )]
      end

      before { single_question(variable: 'mood', values: %w[1 2 3]) }

      it 'sets health_clinic_id on UserIntervention and UserSession' do
        call
        ui = UserIntervention.find_by(intervention_id: intervention.id)
        us = UserSession::ResearchAssistant.find_by(session_id: ra_session.id)
        expect(ui.health_clinic_id).to eq(health_clinic.id)
        expect(us.health_clinic_id).to eq(health_clinic.id)
      end
    end
  end

  describe 'empty payload' do
    let(:payload) { [] }

    it 'returns all-zero counters' do
      expect(call).to include(total: 0, participants_created: 0, failed: 0)
    end
  end
end
