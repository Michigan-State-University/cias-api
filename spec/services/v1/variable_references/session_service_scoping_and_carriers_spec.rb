# frozen_string_literal: true

require 'rails_helper'

# Real-SQL coverage: intervention-scoped days_after_date rewrites, the Question::Feedback carrier,
# the source-session flag and the chart skip. The sibling session_service_spec.rb covers the same
# service with message expectations; these deliberately hit the database, where the defects live.
RSpec.describe V1::VariableReferences::SessionService, type: :service do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let!(:source_session) { create(:session, intervention: intervention, variable: 'old_var') }
  let!(:other_session) { create(:session, intervention: intervention, variable: 'other_var') }

  def feedback_question_in(session, payload)
    create(
      :question_feedback,
      question_group: create(:question_group, session: session),
      body: {
        data: [
          {
            payload: { start_value: '', end_value: '', target_value: '' },
            spectrum: { payload: payload, patterns: [{ match: '1', target: ['1'] }] }
          }
        ]
      }
    )
  end

  def spectrum_payload(question)
    question.reload.body['data'][0]['spectrum']['payload']
  end

  describe 'days_after_date scoping' do
    let!(:scheduled_session) do
      create(:session, intervention: intervention, variable: 'scheduled_var', days_after_date_variable_name: 'old_var.q1')
    end

    let(:other_intervention) { create(:intervention, user: user) }
    let!(:foreign_session) do
      create(:session, intervention: other_intervention, variable: 'old_var', days_after_date_variable_name: 'old_var.q1')
    end

    it 'rewrites the reference inside the target intervention' do
      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(scheduled_session.reload.days_after_date_variable_name).to eq('new_var.q1')
    end

    # Session variables are unique per intervention only, so the same name is live elsewhere. This
    # UPDATE once had no intervention predicate at all and rewrote every one of them.
    it 'leaves an identically-named reference in another intervention untouched' do
      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(foreign_session.reload.days_after_date_variable_name).to eq('old_var.q1')
    end

    # Unanchored, renaming s1 -> s7 rewrote a sibling's 's12.dob' into 's72.dob'. Auto-generated
    # variables are s<random>, so a shared prefix is ordinary, and the collision is inside ONE
    # intervention — scoping alone does not help.
    it 'does not rewrite a sibling variable that merely shares a prefix' do
      sibling_source = create(:session, intervention: intervention, variable: 's1')
      collider = create(:session, intervention: intervention, variable: 'collider_var', days_after_date_variable_name: 's12.dob')

      described_class.call(sibling_source.id, 's1', 's7')

      expect(collider.reload.days_after_date_variable_name).to eq('s12.dob')
    end

    # Unanchored, 's1.s1_score' became 'cloned_s1_1.cloned_s1_1_score' under the clone naming.
    it 'rewrites only the leading segment under the cloned_<var>_<position> naming' do
      clone_source = create(:session, intervention: intervention, variable: 's1')
      scheduled = create(:session, intervention: intervention, variable: 'sched_var', days_after_date_variable_name: 's1.s1_score')

      described_class.call(clone_source.id, 's1', 'cloned_s1_1')

      expect(scheduled.reload.days_after_date_variable_name).to eq('cloned_s1_1.s1_score')
    end

    it 'treats a backslash-ampersand in the new variable name as a literal' do
      scheduled = create(:session, intervention: intervention, variable: 'sched_var', days_after_date_variable_name: 'old_var.q1')

      described_class.call(source_session.id, 'old_var', 'a\&b')

      expect(scheduled.reload.days_after_date_variable_name).to eq('a\&b.q1')
    end

    # Inside the per-pattern loop this fired 1 + Q times, each pass re-matching what the last wrote.
    # A source session with at least one question variable is needed to reproduce it.
    it 'does not compound when the new name extends the old one' do
      compound_source = create(:session, intervention: intervention, variable: 's1')
      create(:question_single, question_group: create(:question_group, session: compound_source))
      scheduled = create(:session, intervention: intervention, variable: 'sched_var', days_after_date_variable_name: 's1.mood')

      described_class.call(compound_source.id, 's1', 's1b')

      expect(scheduled.reload.days_after_date_variable_name).to eq('s1b.mood')
    end

    # A CONTROL, not a falsifiable pin: it passes under every anchor, because the predicate never
    # selects this row. Documents that a question variable sharing the session variable's name is safe.
    it 'does not rewrite a trailing segment that matches the variable name' do
      scheduled = create(:session, intervention: intervention, variable: 'sched_var', days_after_date_variable_name: 'other_var.old_var')

      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(scheduled.reload.days_after_date_variable_name).to eq('other_var.old_var')
    end

    # A trailing \M needs a word-character boundary, so a variable ending in one was selected and
    # then silently left unrewritten.
    it 'rewrites a variable whose name ends in a non-word character' do
      odd_source = create(:session, intervention: intervention, variable: 's-')
      scheduled = create(:session, intervention: intervention, variable: 'sched2_var', days_after_date_variable_name: 's-.dob')

      described_class.call(odd_source.id, 's-', 'renamed')

      expect(scheduled.reload.days_after_date_variable_name).to eq('renamed.dob')
    end

    it 'leaves a reference to a different variable in the same intervention untouched' do
      unrelated = create(:session, intervention: intervention, variable: 'unrelated_var', days_after_date_variable_name: 'someone_else.q1')

      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(unrelated.reload.days_after_date_variable_name).to eq('someone_else.q1')
    end
  end

  describe 'Question::Feedback spectrum carrier' do
    it 'rewrites a spectrum payload in another session of the intervention' do
      question = feedback_question_in(other_session, 'old_var.single_var + 2')

      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(spectrum_payload(question)).to eq('new_var.single_var + 2')
    end

    it 'leaves a spectrum payload naming a different variable alone' do
      question = feedback_question_in(other_session, 'unrelated_var.single_var + 2')

      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(spectrum_payload(question)).to eq('unrelated_var.single_var + 2')
    end

    it 'preserves the position of the spectrum inside the data array' do
      question = create(
        :question_feedback,
        question_group: create(:question_group, session: other_session),
        body: {
          data: [
            { payload: { start_value: 'first', end_value: '', target_value: '' },
              spectrum: { payload: 'old_var.single_var', patterns: [{ match: '1', target: ['1'] }] } },
            { payload: { start_value: 'second', end_value: '', target_value: '' },
              spectrum: { payload: 'old_var.other_q', patterns: [{ match: '2', target: ['2'] }] } }
          ]
        }
      )

      described_class.call(source_session.id, 'old_var', 'new_var')

      data = question.reload.body['data']
      expect(data.map { |row| row['payload']['start_value'] }).to eq(%w[first second])
      expect(data.map { |row| row['spectrum']['payload'] }).to eq(['new_var.single_var', 'new_var.other_q'])
    end
  end

  describe 'include_source_session' do
    it 'does not rewrite the source session by default' do
      question = feedback_question_in(source_session, 'old_var.single_var')

      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(spectrum_payload(question)).to eq('old_var.single_var')
    end

    it 'rewrites the source session when the flag is on' do
      question = feedback_question_in(source_session, 'old_var.single_var')

      described_class.new(source_session.id, 'old_var', 'new_var', include_source_session: true).call

      expect(spectrum_payload(question)).to eq('new_var.single_var')
    end

    # The QueryBuilder flag is either/or, not a superset, so include_source_session: true has to keep
    # covering the other sessions as well or the clone path would silently strand them.
    it 'still rewrites the other sessions when the flag is on' do
      source_question = feedback_question_in(source_session, 'old_var.single_var')
      other_question = feedback_question_in(other_session, 'old_var.single_var')

      described_class.new(source_session.id, 'old_var', 'new_var', include_source_session: true).call

      expect(spectrum_payload(source_question)).to eq('new_var.single_var')
      expect(spectrum_payload(other_question)).to eq('new_var.single_var')
    end
  end

  describe 'source pass through a non-Feedback carrier' do
    # The other source-session examples all go through the Feedback carrier; this is a second one.
    it 'rewrites the source session own formulas payload when the source is included' do
      source_session.update_column(:formulas, [{ 'payload' => 'old_var.single_var > 3', 'patterns' => [] }])

      described_class.new(source_session.id, 'old_var', 'new_var', include_source_session: true).call

      expect(source_session.reload.formulas.first['payload']).to eq('new_var.single_var > 3')
    end

    it 'leaves the source session own formulas payload alone by default' do
      source_session.update_column(:formulas, [{ 'payload' => 'old_var.single_var > 3', 'patterns' => [] }])

      described_class.call(source_session.id, 'old_var', 'new_var')

      expect(source_session.reload.formulas.first['payload']).to eq('old_var.single_var > 3')
    end
  end

  describe 'skip_chart_formulas' do
    it 'rewrites chart formulas by default' do
      service = described_class.new(source_session.id, 'old_var', 'new_var')

      expect(service).to receive(:update_chart_formulas).with(intervention.id, 'old_var', 'new_var')

      service.call
    end

    # On the clone path this would repoint the ORIGINAL's chart at the copy.
    it 'does not rewrite chart formulas when skipped' do
      service = described_class.new(source_session.id, 'old_var', 'new_var', skip_chart_formulas: true)

      expect(service).not_to receive(:update_chart_formulas)

      service.call
    end
  end
end
