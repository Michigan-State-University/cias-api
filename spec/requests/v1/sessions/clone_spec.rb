# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }

  context 'Session::Classic' do
    let(:session) do
      create(:session, :with_report_templates,
             intervention: intervention,
             formulas: [{ 'payload' => 'var + 5', 'patterns' => [
               { 'match' => '=8', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
             ] }],
             settings: { 'formula' => true, 'narrator' => { 'animation' => true, 'voice' => true } },
             days_after_date_variable_name: 'var1')
    end
    let!(:sms_plan) { create(:sms_plan, session: session) }
    let!(:variant) { create(:sms_plan_variant, :with_attachment, sms_plan: sms_plan) }
    let!(:other_session) { create(:session, intervention: intervention) }
    let!(:question_group1) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
    let!(:question_group2) { create(:question_group, title: 'Question Group Title 2', session: session, position: 2) }
    let!(:question1) do
      create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle', position: 1,
                               formulas: [{ 'payload' => 'var + 3', 'patterns' => [
                                 { 'match' => '=7', 'target' => [{ 'id' => question2.id, 'probability' => '100', type: 'Question::Single' }] }
                               ] }])
    end
    let!(:question2) do
      create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle 2', position: 2,
                               formulas: [{ 'payload' => 'var + 4', 'patterns' => [
                                 { 'match' => '=3', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
                               ] }])
    end
    let!(:question3) do
      create(:question_single, question_group: question_group1, subtitle: 'Question Subtitle 3', position: 3,
                               formulas: [{ 'payload' => 'var + 2', 'patterns' => [
                                 { 'match' => '=4', 'target' => [{ 'id' => question4.id, 'probability' => '100', type: 'Question::Single' }] }
                               ] }])
    end
    let!(:question4) do
      create(:question_single, question_group: question_group2, subtitle: 'Question Subtitle 4', position: 1,
                               formulas: [{ 'payload' => 'var + 7', 'patterns' => [
                                 { 'match' => '=11', 'target' => [{ 'id' => question1.id, 'probability' => '100', type: 'Question::Single' }] }
                               ] }])
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
                                   animation: true,
                                   character: 'peedy'
                                 }
                               })
    end
    let!(:question6) do
      create(:question_single, question_group: question_group2, subtitle: 'Question Subtitle 6', position: 3,
                               formulas: [{ 'payload' => '', 'patterns' => [
                                 { 'match' => '', 'target' => [{ 'id' => 'invalid_id', 'probability' => '100', type: 'Question::Single' }] }
                               ] }])
    end
    let!(:last_third_party_report_template) { session.report_templates.third_party.last }
    let!(:question7) do
      create(:question_third_party, question_group: question_group2, subtitle: 'Question Subtitle 7', position: 4,
                                    body: { data: [{ payload: '', value: '', report_template_ids: [last_third_party_report_template.id] }] })
    end

    let(:outcome_sms_plans) { Session.order(:created_at).last.sms_plans }
    let(:outcome_report_templates) { Session.order(:created_at).last.report_templates }
    let(:request) { post v1_clone_session_path(id: session.id), headers: user.create_new_auth_token }

    context 'when auth' do
      context 'is invalid' do
        let(:request) { post v1_clone_session_path(id: session.id) }

        it_behaves_like 'unauthorized user'
      end

      context 'is valid' do
        it_behaves_like 'authorized user'
      end
    end

    context 'not found' do
      let(:invalid_session_id) { '1' }

      before do
        post v1_clone_session_path(id: invalid_session_id), headers: user.create_new_auth_token
      end

      it 'has correct failure http status' do
        expect(response).to have_http_status(:not_found)
      end
    end

    shared_examples 'permitted user' do
      context 'when user clones a session' do
        before { request }

        it 'has correct http code' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when user is researcher' do
      it_behaves_like 'permitted user'

      context 'attachments also are copies' do
        it {
          request
          expect(outcome_sms_plans.last.variants.first.attachment.attached?).to be true
        }
      end
    end

    context 'when user is researcher and have multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[guest researcher participant]) }

      it_behaves_like 'permitted user'
    end
  end

  context 'Session::CatMh' do
    let!(:session) do
      create(:cat_mh_session, :with_cat_mh_info, :with_test_type_and_variables, :with_sms_plans, :with_report_templates, intervention: intervention)
    end
    let(:request) { post v1_clone_session_path(id: session.id), headers: user.create_new_auth_token }

    before { request }

    it 'has correct http code' do
      expect(response).to have_http_status(:ok)
    end
  end
end
