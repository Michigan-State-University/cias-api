# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  context 'Intervention' do
    subject { create(:intervention) }

    let(:initial_status) { subject }

    it { should belong_to(:user) }
    it { should have_many(:sessions) }
    it { should belong_to(:google_language) }
    it { should be_valid }
    it { expect(initial_status.draft?).to be true }
  end

  context 'change states' do
    context 'from draft' do
      let(:intervention) { create(:intervention) }
      let!(:sessions) { create_list(:session, 4, intervention_id: intervention.id) }

      context 'to published' do
        it 'success event' do
          intervention.broadcast
          expect(intervention.published?).to be true
        end
      end

      context 'to closed' do
        it 'no status change' do
          intervention.close
          expect(intervention.draft?).to be true
        end
      end

      context 'to archived' do
        it 'success event' do
          intervention.to_archive
          expect(intervention.archived?).to be true
        end
      end
    end

    context 'from published' do
      let(:intervention) { create(:intervention, :published) }

      context 'to closed' do
        it 'success event' do
          intervention.close
          expect(intervention.closed?).to be true
        end
      end

      context 'to archived' do
        it 'no status change' do
          intervention.to_archive
          expect(intervention.published?).to be true
        end
      end
    end

    context 'from closed' do
      let(:intervention) { create(:intervention, :closed) }

      context 'to published' do
        it 'no status change' do
          intervention.broadcast
          expect(intervention.closed?).to be true
        end
      end

      context 'to archived' do
        it 'success event' do
          intervention.to_archive
          expect(intervention.archived?).to be true
        end
      end
    end

    context 'from archived' do
      let(:intervention) { create(:intervention, :archived) }

      context 'to published' do
        it 'no status change' do
          intervention.broadcast
          expect(intervention.archived?).to be true
        end
      end

      context 'to closed' do
        it 'no status change' do
          intervention.close
          expect(intervention.archived?).to be true
        end
      end
    end
  end

  context 'clone' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:intervention) { create(:intervention) }
    let!(:session) { create(:session, intervention: intervention, position: 1) }
    let!(:other_session) do
      create(:session, intervention: intervention, position: 2,
                       formulas: [{ 'payload' => 'var + 2',
                                    'patterns' =>
                          [{ 'match' => '=1',
                             'target' =>
                               [{ 'id' => third_session.id, 'type' => 'Session' }] }] }])
    end
    let!(:third_session) do
      create(:session, intervention: intervention, position: 3,
                       formulas: [{ 'payload' => '',
                                    'patterns' =>
                          [{ 'match' => '',
                             'target' =>
                               [{ 'id' => '', 'type' => 'Session' }] }] }])
    end
    let!(:question_group) { create(:question_group, title: 'Question Group Title', session: session) }
    let!(:question1) do
      create(:question_single, question_group: question_group, subtitle: 'Question Subtitle', position: 1,
                               formulas: [{ 'payload' => 'var + 3', 'patterns' => [
                                 { 'match' => '=7', 'target' => [{ 'id' => question2.id, type: 'Question::Single' }] }
                               ] }])
    end
    let!(:question2) do
      create(:question_single, question_group: question_group, subtitle: 'Question Subtitle 2', position: 2,
                               formulas: [{ 'payload' => 'var + 4', 'patterns' => [
                                 { 'match' => '=3', 'target' => [{ 'id' => other_session.id, type: 'Session' }] }
                               ] }])
    end

    it 'return correct data' do
      cloned_intervention = intervention.clone

      expect(intervention.attributes.except('id', 'created_at', 'updated_at', 'status', 'name')).to eq(cloned_intervention.attributes.except('id', 'created_at', 'updated_at', 'status', 'name'))
      expect(cloned_intervention.status).to eq('draft')
      expect(cloned_intervention.name).to include('Copy of')
    end

    it 'correct clone questions to cloned session' do
      cloned_intervention = intervention.clone
      cloned_sessions = cloned_intervention.sessions.order(:position)
      cloned_questions = cloned_sessions.first.questions.order(:position)
      expect(cloned_questions.map(&:attributes)).to include(
        include(
          'subtitle' => 'Question Subtitle',
          'position' => 1,
          'body' => include(
            'variable' => { 'name' => 'single_var' }
          ),
          'formulas' => [{
            'payload' => 'var + 3',
            'patterns' => [
              { 'match' => '=7', 'target' => [{ 'id' => cloned_questions.second.id, 'type' => 'Question::Single' }] }
            ]
          }]
        ),
        include(
          'subtitle' => 'Question Subtitle 2',
          'position' => 2,
          'body' => include(
            'variable' => { 'name' => 'single_var' }
          ),
          'formulas' => [{
            'payload' => 'var + 4',
            'patterns' => [
              { 'match' => '=3', 'target' => [{ 'id' => cloned_sessions.second.id, 'type' => 'Session' }] }
            ]
          }]
        ),
        include(
          'position' => 999_999,
          'type' => 'Question::Finish'
        )
      )
    end

    it 'correctly clones sessions with proper connections between other sessions' do
      cloned_intervention = intervention.clone
      cloned_sessions = cloned_intervention.sessions.order(:position)
      second_cloned_session = cloned_sessions.second
      third_cloned_session = cloned_sessions.third

      expect(second_cloned_session.attributes).to include(
        'position' => 2,
        'formulas' => [{
          'payload' => 'var + 2',
          'patterns' => [
            { 'match' => '=1', 'target' => [{ 'id' => third_cloned_session.id, 'type' => 'Session' }] }
          ]
        }]
      )
      expect(third_cloned_session.attributes).to include(
        'position' => 3,
        'formulas' => [{
          'payload' => '',
          'patterns' => [
            { 'match' => '', 'target' => [{ 'id' => '', 'type' => 'Session' }] }
          ]
        }],
        'variable' => third_session.variable.to_s
      )
    end

    context 'when researcher want to assign the intervention to other resarcher' do
      let(:other_user) { create(:user, :confirmed, :researcher) }
      let(:params) { { user_ids: [other_user.id] } }

      it 'create a new intervention with correct user_id' do
        cloned_intervention = intervention.clone(params: params)

        expect(cloned_intervention.first.user_id).to eq(other_user.id)
      end
    end
  end
end
