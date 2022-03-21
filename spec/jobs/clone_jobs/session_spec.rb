# frozen_string_literal: true

RSpec.describe CloneJobs::Session, type: :job do
  include ActiveJob::TestHelper
  subject { described_class.perform_now(user, session) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }

  context 'Session::Classic' do
    let!(:session) do
      create(:session, :with_report_templates, intervention: intervention, position: 1, formula: { 'payload' => 'var + 5', 'patterns' => [
               { 'match' => '=8', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
             ] },
                                               settings: { 'formula' => true, 'narrator' => { 'animation' => true, 'voice' => true } },
                                               days_after_date_variable_name: 'var1')
    end
    let!(:other_session) { create(:session, intervention: intervention, position: 2) }
    let!(:sms_plan) { create(:sms_plan, session: session) }
    let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
    let!(:question_group1) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
    let!(:question_group2) { create(:question_group, title: 'Question Group Title 2', session: session, position: 2) }
    let!(:question1) do
      create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle', position: 1,
                               formula: { 'payload' => 'var + 3', 'patterns' => [
                                 { 'match' => '=7', 'target' => [{ 'id' => question2.id, 'probability' => '100', type: 'Question::Single' }] }
                               ] })
    end
    let!(:question2) do
      create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle 2', position: 2,
                               formula: { 'payload' => 'var + 4', 'patterns' => [
                                 { 'match' => '=3', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
                               ] })
    end
    let!(:question3) do
      create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle 3', position: 3,
                               formula: { 'payload' => 'var + 2', 'patterns' => [
                                 { 'match' => '=4', 'target' => [{ 'id' => question4.id, 'probability' => '100', type: 'Question::Single' }] }
                               ] })
    end
    let!(:question4) do
      create(:question_single, question_group: question_group2, subtitle: 'Question Subtitle 4', position: 1,
                               formula: { 'payload' => 'var + 7', 'patterns' => [
                                 { 'match' => '=11', 'target' => [{ 'id' => question1.id, 'probability' => '100', type: 'Question::Single' }] }
                               ] })
    end

    let!(:question5) do
      create(:question_single, question_group: question_group2, subtitle: 'Question Subtitle 5', position: 2,
                               narrator: {
                                 blocks: [
                                   {
                                     action: 'NO_ACTION',
                                     question_id: question3.id,
                                     reflections: [],
                                     animation: 'pointUp',
                                     type: 'Reflection',
                                     endPosition: {
                                       x: 0,
                                       y: 600
                                     }
                                   }
                                 ],
                                 settings: {
                                   voice: true,
                                   animation: true
                                 }
                               })
    end
    let!(:question6) do
      create(:question_single, question_group: question_group2, subtitle: 'Question Subtitle 6', position: 3,
                               formula: { 'payload' => '', 'patterns' => [
                                 { 'match' => '', 'target' => [{ 'id' => 'invalid_id', 'probability' => '100', type: 'Question::Single' }] }
                               ] })
    end
    let!(:last_third_party_report_template) { session.report_templates.third_party.last }
    let!(:question7) do
      create(:question_third_party, question_group: question_group2, subtitle: 'Question Subtitle 7', position: 4,
                                    body: { data: [{ payload: '', value: '', report_template_ids: [last_third_party_report_template.id] }] })
    end

    before do
      ActiveJob::Base.queue_adapter = :test
      allow(Intervention).to receive(:clone)
    end

    context 'email notifications enabled' do
      it 'send email' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      end

      it 'change session counter' do
        expect { subject }.to change(Session, :count).by(1)
      end
    end

    context 'email notifications disabled' do
      let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

      it "Don't send email" do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0)
      end

      it 'change session counter' do
        expect { subject }.to change(Session, :count).by(1)
      end
    end

    context 'when user cloned a session' do
      subject { described_class.perform_now(user, session) }

      before do
        subject
      end

      let(:cloned_session) { intervention.reload.sessions.order(:position).last }
      let(:session_was) do
        session.attributes.except('id', 'generated_report_count', 'created_at', 'updated_at', 'position', 'sms_plans_count',
                                  'last_report_template_number', 'formula', 'settings', 'days_after_date_variable_name',
                                  'google_tts_voice_id', 'language_name', 'google_tts_voice', 'name')
      end
      let(:cloned_questions_collection) do
        Question.unscoped.includes(:question_group).where(question_groups: { session_id: cloned_session.id })
                .order('question_groups.position' => 'asc', 'questions.position' => 'asc')
      end
      let(:outcome_report_templates) { Session.order(:created_at).last.report_templates }
      let(:outcome_sms_plans) { Session.order(:created_at).last.sms_plans }

      it 'add new session to intervention' do
        expect(intervention.reload.sessions.count).to be(3)
      end

      it 'origin and outcome same except variable' do
        expect(session_was.except('variable')).to eq(cloned_session.attributes.except('id', 'generated_report_count', 'created_at', 'updated_at', 'position',
                                                                                      'sms_plans_count', 'logo_url', 'formula', 'settings',
                                                                                      'days_after_date_variable_name', 'google_tts_voice_id',
                                                                                      'language_name', 'google_tts_voice', 'variable',
                                                                                      'last_report_template_number', 'name'))
        expect(cloned_session.attributes['variable']).to eq "cloned_#{session.variable}_#{intervention.sessions.count}"
      end

      it 'has correct position' do
        expect(cloned_session.position).to be(3)
      end

      it 'has cleared formula' do
        expect(cloned_session.attributes['formula']).to include(
          'payload' => '',
          'patterns' => []
        )
        expect(cloned_session.attributes['settings']['formula']).to eq(false)
      end

      it 'has cleared days_after_variable_name value' do
        expect(cloned_session.attributes['days_after_date_variable_name']).to eq(nil)
      end

      it 'has correct number of question groups' do
        expect(cloned_session.question_groups.size).to eq(3)
      end

      it 'has one finish question_group' do
        expect(cloned_session.question_groups.where(type: 'QuestionGroup::Finish').size).to eq(1)
      end

      it 'correctly clone questions (question group 1)' do
        expect(cloned_questions_collection.map(&:attributes)).to include(
          include(
            'subtitle' => 'Question Subtitle',
            'position' => 1,
            'body' => include(
              'variable' => { 'name' => 'single_var' }
            ),
            'formula' => {
              'payload' => 'var + 3',
              'patterns' => [
                { 'match' => '=7', 'target' => [{ 'id' => cloned_questions_collection.second.id, 'type' => 'Question::Single', 'probability' => '100' }] }
              ]
            }
          ),
          include(
            'subtitle' => 'Question Subtitle 2',
            'position' => 2,
            'body' => include(
              'variable' => { 'name' => 'single_var' }
            ),
            'formula' => {
              'payload' => 'var + 4',
              'patterns' => [
                { 'match' => '=3', 'target' => [{ 'id' => other_session.id, 'type' => 'Session', 'probability' => '100' }] }
              ]
            }
          ),
          include(
            'subtitle' => 'Question Subtitle 3',
            'position' => 3,
            'body' => include(
              'variable' => { 'name' => 'single_var' }
            ),
            'formula' => {
              'payload' => 'var + 2',
              'patterns' => [
                { 'match' => '=4', 'target' => [{ 'id' => cloned_questions_collection.fourth.id, 'type' => 'Question::Single', 'probability' => '100' }] }
              ]
            }
          )
        )
      end

      it 'correctly clone questions (question group 2)' do
        expect(cloned_questions_collection.map(&:attributes)).to include(
          include(
            'subtitle' => 'Question Subtitle 4',
            'position' => 1,
            'body' => include(
              'variable' => { 'name' => 'single_var' }
            ),
            'formula' => {
              'payload' => 'var + 7',
              'patterns' => [
                { 'match' => '=11', 'target' => [{ 'id' => cloned_questions_collection.first.id, 'type' => 'Question::Single', 'probability' => '100' }] }
              ]
            }
          ),
          include(
            'subtitle' => 'Question Subtitle 5',
            'position' => 2,
            'body' => include(
              'variable' => { 'name' => 'single_var' }
            ),
            'narrator' => {
              'blocks' => [
                {
                  'type' => 'Reflection', 'question_id' => cloned_questions_collection.third.id, 'action' => 'NO_ACTION', 'reflections' => [],
                  'animation' => 'pointUp', 'endPosition' => { 'x' => 0, 'y' => 600 }
                }
              ],
              'settings' => {
                'voice' => true,
                'animation' => true
              }
            }
          ),
          include(
            'subtitle' => 'Question Subtitle 6',
            'position' => 3,
            'body' => include(
              'variable' => { 'name' => 'single_var' }
            ),
            'formula' => {
              'payload' => '',
              'patterns' => [
                { 'match' => '', 'target' => [{ 'id' => '', 'type' => 'Question::Single', 'probability' => '100' }] }
              ]
            }
          )
        )
      end

      it 'correctly clone third-party question and assign cloned report template id' do
        expect(cloned_questions_collection.map(&:attributes)).to include(
          include(
            'subtitle' => 'Question Subtitle 7',
            'position' => 4,
            'body' => {
              'data' => [{
                'payload' => '',
                'value' => '',
                'report_template_ids' => [outcome_report_templates.where(name: last_third_party_report_template.name).last.id]
              }]
            }
          )
        )
      end

      it 'correctly clone sms plans' do
        expect(outcome_sms_plans.size).to eq 1
        outcome_sms_plan = outcome_sms_plans.last

        expect(outcome_sms_plan.variants.size).to eq 1
        expect(outcome_sms_plan.slice(*SmsPlan::ATTR_NAMES_TO_COPY)).to eq sms_plan.slice(
          *SmsPlan::ATTR_NAMES_TO_COPY
        )
        expect(outcome_sms_plan.variants.last.slice(*SmsPlan::Variant::ATTR_NAMES_TO_COPY)).to eq variant.slice(
          *SmsPlan::Variant::ATTR_NAMES_TO_COPY
        )
      end

      it 'correctly clones report templates' do
        expect(outcome_report_templates.size).to eq 2

        outcome_report_template = outcome_report_templates.order(:created_at).last
        report_template = session.report_templates.order(:created_at).last

        expect(outcome_report_template.variants.size).to eq 1
        expect(outcome_report_template.sections.size).to eq 1

        expect(outcome_report_template.slice(*ReportTemplate::ATTR_NAMES_TO_COPY)).to eq report_template.slice(
          *ReportTemplate::ATTR_NAMES_TO_COPY
        )
        expect(outcome_report_template.sections.last.slice(*ReportTemplate::Section::ATTR_NAMES_TO_COPY)).to eq report_template.sections.last.slice(
          *ReportTemplate::Section::ATTR_NAMES_TO_COPY
        )
        expect(outcome_report_template.variants.last.slice(*ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY)).to eq report_template.variants.last.slice(
          *ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY
        )
      end
    end
  end

  context 'Session::CatMh' do
    let!(:session) do
      create(:cat_mh_session, :with_cat_mh_info, :with_test_type_and_variables, :with_sms_plans, :with_report_templates, intervention: intervention)
    end
    let(:outcome_cat_mh_test_types) { Session.order(:created_at).last.cat_mh_test_types }
    let(:outcome_sms_plans) { Session.order(:created_at).last.sms_plans }
    let(:outcome_cat_mh_test_types) { Session.order(:created_at).last.cat_mh_test_types }
    let(:outcome_report_templates) { Session.order(:created_at).last.report_templates }

    before { subject }

    it 'correctly clone sms plans' do
      expect(outcome_sms_plans.size).to eq 2
    end

    it 'correctly clone tests' do
      expect(outcome_cat_mh_test_types.size).to eq(session.cat_mh_test_types.size)
      expect(outcome_cat_mh_test_types).to eq(session.cat_mh_test_types)
    end

    it 'correctly clones report templates' do
      expect(outcome_report_templates.size).to eq 2

      outcome_report_template = outcome_report_templates.order(:created_at).last
      report_template = session.report_templates.order(:created_at).last

      expect(outcome_report_template.variants.size).to eq 1
      expect(outcome_report_template.sections.size).to eq 1

      expect(outcome_report_template.slice(*ReportTemplate::ATTR_NAMES_TO_COPY)).to eq report_template.slice(
        *ReportTemplate::ATTR_NAMES_TO_COPY
      )
      expect(outcome_report_template.sections.last.slice(*ReportTemplate::Section::ATTR_NAMES_TO_COPY)).to eq report_template.sections.last.slice(
        *ReportTemplate::Section::ATTR_NAMES_TO_COPY
      )
      expect(outcome_report_template.variants.last.slice(*ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY)).to eq report_template.variants.last.slice(
        *ReportTemplate::Section::Variant::ATTR_NAMES_TO_COPY
      )
    end
  end
end
