# frozen_string_literal: true

require 'rails_helper'

# Duplicating an intervention used to copy session variables verbatim, so an original and its copy on
# the same organization dashboard collided. These cover the rename and the references that follow it.
RSpec.describe Clone::Intervention, type: :model do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let!(:session1) { create(:session, intervention: intervention, variable: 's1', position: 1) }
  let!(:session2) { create(:session, intervention: intervention, variable: 's2', position: 2) }
  let!(:question1) { create(:question_single, question_group: create(:question_group, session: session1)) }

  def copy_sessions(copy)
    copy.sessions.where.not(position: 0).order(:position)
  end

  describe 'renaming' do
    let!(:session3) { create(:session, intervention: intervention, variable: 's3', position: 3) }

    it 'renames every session variable to cloned_<var>_<position>' do
      copy = intervention.clone

      expect(copy_sessions(copy).pluck(:variable)).to eq(%w[cloned_s1_1 cloned_s2_2 cloned_s3_3])
    end

    it 'leaves the source intervention session variables unchanged' do
      intervention.clone

      expect(intervention.sessions.order(:position).pluck(:variable)).to eq(%w[s1 s2 s3])
    end
  end

  describe 'references inside the copy follow the rename' do
    it 'rewrites a cross-session formulas payload' do
      session2.update_column(:formulas, [{ 'payload' => 's1.single_var > 3', 'patterns' => [] }])

      copy = intervention.clone

      copied = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      expect(copied.formulas.first['payload']).to eq('cloned_s1_1.single_var > 3')
    end

    it 'rewrites a days_after_date scheduling reference' do
      session2.update_column(:days_after_date_variable_name, 's1.single_var')

      copy = intervention.clone

      copied = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      expect(copied.days_after_date_variable_name).to eq('cloned_s1_1.single_var')
    end

    # Text interpolation, not a formula — a scan for `formula` columns misses these entirely.
    it 'rewrites .:var:. tokens in an sms plan no_formula_text' do
      create(:sms_plan, session: session2, no_formula_text: 'score .:s1.single_var:. today')

      copy = intervention.clone

      copied = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      expect(copied.sms_plans.first.no_formula_text).to eq('score .:cloned_s1_1.single_var:. today')
    end

    it 'rewrites .:var:. tokens in an sms plan variant content' do
      plan = create(:sms_plan, session: session2, formula: 's1.single_var', is_used_formula: true)
      create(:sms_plan_variant, sms_plan: plan, content: 'you scored .:s1.single_var:.', formula_match: '=')

      copy = intervention.clone

      copied = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      expect(copied.sms_plans.first.variants.first.content).to eq('you scored .:cloned_s1_1.single_var:.')
      expect(copied.sms_plans.first.formula).to eq('cloned_s1_1.single_var')
    end

    it 'rewrites .:var:. tokens in a report template section variant content' do
      template = create(:report_template, session: session2)
      section = create(:report_template_section, report_template: template, formula: 's1.single_var')
      create(:report_template_section_variant, report_template_section: section,
                                               content: 'your score is .:s1.single_var:.', formula_match: '=1')

      copy = intervention.clone

      copied_session = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      copied_variant = copied_session.report_templates.first.sections.first.variants.first
      expect(copied_variant.content).to eq('your score is .:cloned_s1_1.single_var:.')
      expect(copied_session.report_templates.first.sections.first.formula).to eq('cloned_s1_1.single_var')
    end
  end

  describe 'the rename touches references, not prose' do
    let!(:named) { create(:session, intervention: intervention, variable: 'baseline', position: 4) }

    it 'rewrites the .:svar.qvar:. token and leaves the English word alone' do
      create(:sms_plan, session: session2, no_formula_text: 'Since baseline you scored .:baseline.single_var:.')

      copy = intervention.clone

      copied = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      expect(copied.sms_plans.first.no_formula_text).to eq('Since baseline you scored .:cloned_baseline_4.single_var:.')
    end

    it 'does not shadow a question variable that shares the session variable name' do
      question = create(:question_single, question_group: create(:question_group, session: session2))
      body = question.body
      body['variable'] = { 'name' => 'baseline' }
      question.update_column(:body, body)
      question.update_column(:formulas, [{ 'payload' => 'baseline > 3', 'patterns' => [] }])

      copy = intervention.clone

      copied_session = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      copied_question = Question.unscoped.joins(:question_group)
                                .find_by(question_groups: { session_id: copied_session.id }, type: 'Question::Single')
      expect(copied_question.formulas.first['payload']).to eq('baseline > 3')
    end
  end

  describe 'the remaining carriers on the copy' do
    it 'rewrites a Question::Feedback spectrum payload' do
      create(:question_feedback,
             question_group: create(:question_group, session: session2),
             body: { data: [{ payload: { start_value: '', end_value: '', target_value: '' },
                              spectrum: { payload: 's1.single_var + 2', patterns: [{ match: '1', target: ['1'] }] } }] })

      copy = intervention.clone

      copied_session = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      question = Question.unscoped.joins(:question_group)
                         .find_by(question_groups: { session_id: copied_session.id }, type: 'Question::Feedback')
      expect(question.body['data'].first['spectrum']['payload']).to eq('cloned_s1_1.single_var + 2')
    end

    it 'rewrites a questions.formulas payload' do
      question = create(:question_single, question_group: create(:question_group, session: session2))
      question.update_column(:formulas, [{ 'payload' => 's1.single_var > 3', 'patterns' => [] }])

      copy = intervention.clone

      copied_session = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      copied_question = Question.unscoped.joins(:question_group)
                                .find_by(question_groups: { session_id: copied_session.id }, type: 'Question::Single')
      expect(copied_question.formulas.first['payload']).to eq('cloned_s1_1.single_var > 3')
    end

    it 'rewrites a question_groups.formulas payload' do
      group = create(:question_group, session: session2)
      group.update_column(:formulas, [{ 'payload' => 's1.single_var > 3', 'patterns' => [] }])

      copy = intervention.clone

      copied_session = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      copied_group = copied_session.question_groups.find_by(title: group.title)
      expect(copied_group.formulas.first['payload']).to eq('cloned_s1_1.single_var > 3')
    end
  end

  describe 'ordering against the clone own JSONB passes' do
    # The behavioural example below passes in BOTH orders (reassign_reflections re-queries, so there
    # is no stale-object clobber path). Only a call-order assertion can pin the ordering.
    it 'runs the rewrite strictly after the reflection reassignment' do
      cloner = described_class.new(intervention, {})

      expect(cloner).to receive(:reassign_reflections).ordered.and_call_original
      expect(cloner).to receive(:apply_session_variable_renames).ordered.and_call_original

      cloner.execute
    end

    it 'keeps both the reflection re-pointing and the rewrite' do
      question2 = create(:question_single, question_group: create(:question_group, session: session2))
      question2.update_column(:narrator, {
                                'blocks' => [
                                  { 'type' => 'Reflection', 'question_id' => question1.id, 'session_id' => session1.id,
                                    'question_group_id' => question1.question_group_id, 'reflections' => [] },
                                  { 'type' => 'ReflectionFormula', 'payload' => 's1.single_var > 2', 'reflections' => [] }
                                ],
                                'settings' => { 'voice' => false, 'animation' => true, 'character' => 'peedy' }
                              })

      copy = intervention.clone

      copied_session = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      copied_question = Question.unscoped.joins(:question_group)
                                .find_by(question_groups: { session_id: copied_session.id }, type: 'Question::Single')
      blocks = copied_question.narrator['blocks']

      expect(blocks.find { |b| b['type'] == 'ReflectionFormula' }['payload']).to eq('cloned_s1_1.single_var > 2')
      reflection = blocks.find { |b| b['type'] == 'Reflection' }
      expect(reflection['session_id']).not_to eq(session1.id)
      expect(reflection['session_id']).to be_present
    end
  end

  describe 'the source intervention is untouched' do
    # Seeds all nine carriers plus the Feedback spectrum on the SOURCE and asserts each is unchanged.
    it 'does not rewrite any of the nine source carriers' do
      payload = 's1.single_var > 3'
      token = 'score .:s1.single_var:.'

      session2.update_column(:formulas, [{ 'payload' => payload, 'patterns' => [] }])
      session2.update_column(:days_after_date_variable_name, 's1.single_var')
      group = create(:question_group, session: session2)
      group.update_column(:formulas, [{ 'payload' => payload, 'patterns' => [] }])
      question = create(:question_single, question_group: group)
      question.update_column(:formulas, [{ 'payload' => payload, 'patterns' => [] }])
      question.update_column(:narrator, { 'blocks' => [{ 'type' => 'ReflectionFormula', 'payload' => payload, 'reflections' => [] }],
                                          'settings' => { 'voice' => false, 'animation' => true, 'character' => 'peedy' } })
      feedback = create(:question_feedback, question_group: group,
                                            body: { data: [{ payload: { start_value: '', end_value: '', target_value: '' },
                                                             spectrum: { payload: payload, patterns: [{ match: '1', target: ['1'] }] } }] })
      plan = create(:sms_plan, session: session2, formula: payload, no_formula_text: token, is_used_formula: true)
      variant = create(:sms_plan_variant, sms_plan: plan, content: token, formula_match: '=')
      template = create(:report_template, session: session2)
      section = create(:report_template_section, report_template: template, formula: payload)
      section_variant = create(:report_template_section_variant, report_template_section: section, content: token, formula_match: '=1')

      intervention.clone

      expect(session2.reload.formulas.first['payload']).to eq(payload)
      expect(session2.days_after_date_variable_name).to eq('s1.single_var')
      expect(group.reload.formulas.first['payload']).to eq(payload)
      expect(question.reload.formulas.first['payload']).to eq(payload)
      expect(question.narrator['blocks'].first['payload']).to eq(payload)
      expect(feedback.reload.body['data'].first['spectrum']['payload']).to eq(payload)
      expect(plan.reload.formula).to eq(payload)
      expect(plan.no_formula_text).to eq(token)
      expect(variant.reload.content).to eq(token)
      expect(section.reload.formula).to eq(payload)
      expect(section_variant.reload.content).to eq(token)
    end

    # The scheduling rewrite was once table-wide; this proves the scoping holds on the clone path.
    it 'does not touch an unrelated intervention sharing the variable name' do
      other = create(:intervention, user: user)
      other_session = create(:session, intervention: other, variable: 'other_s1', position: 1,
                                       days_after_date_variable_name: 's1.single_var')

      intervention.clone

      expect(other_session.reload.days_after_date_variable_name).to eq('s1.single_var')
    end
  end

  describe 'the translation path is exempt' do
    it 'keeps the source session variables when renaming is switched off' do
      copy = intervention.clone(hidden: true, rename_session_variables: false)

      expect(copy_sessions(copy).pluck(:variable)).to eq(%w[s1 s2])
    end

    # Pins the wiring, not just the flag. A non-nil language id is required or #call returns before
    # reaching the clone.
    it 'is how V1::Translations::Intervention clones' do
      allow(V1::Google::TranslationService).to receive(:new).and_return(instance_double(V1::Google::TranslationService))
      allow(intervention).to receive_messages(clone: intervention, translate: nil)

      V1::Translations::Intervention.new(intervention, 1, nil).call

      expect(intervention).to have_received(:clone).with(hidden: true, rename_session_variables: false)
    end
  end

  describe 'idempotence' do
    it 'changes nothing when the same rename is replayed' do
      session2.update_column(:formulas, [{ 'payload' => 's1.single_var > 3', 'patterns' => [] }])

      copy = intervention.clone
      copied = copy_sessions(copy).find_by(variable: 'cloned_s2_2')
      first_pass = copied.formulas.first['payload']

      cloned_s1 = copy_sessions(copy).find_by(variable: 'cloned_s1_1')
      V1::VariableReferences::SessionService.new(cloned_s1.id, 's1', 'cloned_s1_1',
                                                 include_source_session: true, skip_chart_formulas: true).call

      expect(copied.reload.formulas.first['payload']).to eq(first_pass)
    end
  end

  describe 'refusing a rename that would alias another session' do
    # One session's new name being another's old name silently repoints references; reachable
    # because Session#variable has no format validation.
    it 'refuses to clone when a new session variable is another session old variable' do
      create(:session, intervention: intervention, variable: 'cloned_s1_1', position: 4)

      expect { intervention.clone }.to raise_error(ArgumentError, /collide/)
    end
  end

  describe 'collision inside the target intervention' do
    it 'raises and leaves the partial clone behind (see the comment)' do
      allow_any_instance_of(described_class).to receive(:cloned_session_variable).and_return('duplicated_var')

      before_count = Intervention.count

      expect { intervention.clone }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Intervention.count).to eq(before_count + 1)
      # NOT cleaned up: CloneJobs::Intervention's rescue reads `cloned_interventions`, still nil when
      # `clone` raises, so Array(nil) => [] and the cleanup is a no-op. The orphan stays hidden.
      orphan = Intervention.order(:created_at).last
      expect(orphan.is_hidden).to be(true)
      expect(orphan.sessions.count).to be_positive
    end
  end
end
