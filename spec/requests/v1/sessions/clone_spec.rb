# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }

  let(:outcome_sms_plans) { Session.order(:created_at).last.sms_plans }
  let(:outcome_report_templates) { Session.order(:created_at).last.report_templates }
  let(:request) { post v1_clone_session_path(id: session.id), headers: user.create_new_auth_token }

  context 'Session::Classic' do
    let(:session) do
      create(:session, :with_report_templates,
             intervention: intervention,
             formula: { 'payload' => 'var + 5', 'patterns' => [
               { 'match' => '=8', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
             ] },
             settings: { 'formula' => true, 'narrator' => { 'animation' => true, 'voice' => true } },
             days_after_date_variable_name: 'var1')
    end
    let!(:sms_plan) { create(:sms_plan, session: session) }
    let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
    let!(:other_session) { create(:session, intervention: intervention) }
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
  end

  shared_examples 'permitted user' do
    context 'when user clones a session' do
      before { request }

      it 'has correct http code' do
        expect(response).to have_http_status(:ok)
      end
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
