# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: user) }
  let(:session) do
    create(:session, :with_report_templates,
           intervention: intervention,
           formula: { 'payload' => 'var + 5', 'patterns' => [
             { 'match' => '=8', 'target' => { 'id' => other_session.id, type: 'Session' } }
           ] },
           settings: { 'formula' => true, 'narrator' => { 'animation' => true, 'voice' => true } },
           days_after_date_variable_name: 'var1')
  end
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
  let!(:other_session) { create(:session) }
  let!(:question_group_1) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
  let!(:question_group_2) { create(:question_group, title: 'Question Group Title 2', session: session, position: 2) }
  let!(:question_1) do
    create(:question_single, question_group: question_group_1, subtitle: 'Question Subtitle', position: 1,
                             formula: { 'payload' => 'var + 3', 'patterns' => [
                               { 'match' => '=7', 'target' => { 'id' => question_2.id, type: 'Question::Single' } }
                             ] })
  end
  let!(:question_2) do
    create(:question_single, question_group: question_group_1, subtitle: 'Question Subtitle 2', position: 2,
                             formula: { 'payload' => 'var + 4', 'patterns' => [
                               { 'match' => '=3', 'target' => { 'id' => other_session.id, type: 'Session' } }
                             ] })
  end
  let!(:question_3) do
    create(:question_single, question_group: question_group_1, subtitle: 'Question Subtitle 3', position: 3,
                             formula: { 'payload' => 'var + 2', 'patterns' => [
                               { 'match' => '=4', 'target' => { 'id' => question_4.id, type: 'Question::Single' } }
                             ] })
  end
  let!(:question_4) do
    create(:question_single, question_group: question_group_2, subtitle: 'Question Subtitle 4', position: 1,
                             formula: { 'payload' => 'var + 7', 'patterns' => [
                               { 'match' => '=11', 'target' => { 'id' => question_1.id, type: 'Question::Single' } }
                             ] })
  end

  let!(:question_5) do
    create(:question_single, question_group: question_group_2, subtitle: 'Question Subtitle 5', position: 2,
                             narrator: {
                               blocks: [
                                 {
                                   action: 'NO_ACTION',
                                   question_id: question_3.id,
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
  let!(:question_6) do
    create(:question_single, question_group: question_group_2, subtitle: 'Question Subtitle 6', position: 3,
                             formula: { 'payload' => '', 'patterns' => [
                               { 'match' => '', 'target' => { 'id' => '', type: 'Question::Single' } }
                             ] })
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

    it 'has correct failure message' do
      expect(json_response['message']).to include("Couldn't find Session with 'id'=#{invalid_session_id}")
    end
  end

  context 'when user clones a session' do
    before { request }

    let(:cloned_session_id) { json_response['data']['id'] }
    let(:cloned_session) { Session.find(json_response['data']['id']) }
    let(:cloned_questions_collection) do
      Question.unscoped.includes(:question_group).where(question_groups: { session_id: cloned_session_id })
              .order('question_groups.position' => 'asc', 'questions.position' => 'asc')
    end
    let(:cloned_question_groups) { cloned_session.question_groups.order(:position) }

    let(:session_was) do
      session.attributes.except('id', 'generated_report_count', 'created_at', 'updated_at', 'position', 'sms_plans_count',
                                'last_report_template_number', 'formula', 'settings', 'days_after_date_variable_name',
                                'google_tts_voice_id', 'language_name', 'google_tts_voice')
    end

    let(:session_cloned) do
      json_response['data']['attributes'].except('id', 'generated_report_count', 'created_at', 'updated_at', 'position',
                                                 'sms_plans_count', 'logo_url', 'formula', 'settings', 'days_after_date_variable_name',
                                                 'google_tts_voice_id', 'language_name', 'google_tts_voice')
    end

    let(:session_cloned_position) { intervention.sessions.order(:position).last.position + 1 }

    it 'has correct http code' do
      expect(response).to have_http_status(:created)
    end

    it 'origin and outcome same except variable' do
      expect(session_was.except('variable')).to eq(session_cloned.except('variable'))
      expect(session_cloned['variable']).to eq "cloned_#{session.variable}_#{session_cloned_position}"
    end

    it 'has correct position' do
      expect(json_response['data']['attributes']['position']).to eq(2)
    end

    it 'has cleared formula' do
      expect(json_response['data']['attributes']['formula']).to include(
        'payload' => '',
        'patterns' => []
      )
      expect(json_response['data']['attributes']['settings']['formula']).to eq(false)
    end

    it 'has cleared days_after_date_variable_name value' do
      expect(json_response['data']['attributes']['days_after_date_variable_name']).to eq(nil)
    end

    it 'has correct number of sessions' do
      expect(session.intervention.sessions.size).to eq(2)
    end

    it 'has correct number of question_groups' do
      expect(cloned_session.question_groups.size).to eq(3)
    end

    it 'has one finish question_group' do
      expect(cloned_session.question_groups.where(type: 'QuestionGroup::Finish').size).to eq(1)
    end

    it 'has one finish question' do
      expect(cloned_questions_collection.where(type: 'Question::Finish').size).to eq(1)
    end

    it 'correctly clone questions' do
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
              { 'match' => '=7', 'target' => { 'id' => cloned_questions_collection.second.id, 'type' => 'Question::Single' } }
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
              { 'match' => '=3', 'target' => { 'id' => other_session.id, 'type' => 'Session' } }
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
              { 'match' => '=4', 'target' => { 'id' => cloned_questions_collection.fourth.id, 'type' => 'Question::Single' } }
            ]
          }
        ),
        include(
          'subtitle' => 'Question Subtitle 4',
          'position' => 1,
          'body' => include(
            'variable' => { 'name' => 'single_var' }
          ),
          'formula' => {
            'payload' => 'var + 7',
            'patterns' => [
              { 'match' => '=11', 'target' => { 'id' => cloned_questions_collection.first.id, 'type' => 'Question::Single' } }
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
              { 'match' => '', 'target' => { 'id' => '', 'type' => 'Question::Single' } }
            ]
          }
        ),
        include(
          'position' => 999_999,
          'type' => 'Question::Finish'
        )
      )
    end

    it 'finish question has only one speech' do
      expect(cloned_questions_collection.where(type: 'Question::Finish').first.narrator['blocks'].size).to eq(1)
      expect(cloned_questions_collection.where(type: 'Question::Finish').first.narrator['blocks'][0]).to include(
        'text' => ['Finish Screen'],
        'type' => 'ReadQuestion',
        'action' => 'NO_ACTION',
        'animation' => 'rest',
        'endPosition' => { 'x' => 600, 'y' => 550 }
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
