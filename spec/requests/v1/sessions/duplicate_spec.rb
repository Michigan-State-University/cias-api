# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/intervention/:intervention_id/sessions/:id/duplicate', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:researcher_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
  let(:user) { researcher }
  let(:users) do
    {
      'researcher' => researcher,
      'researcher_with_multiple_roles' => researcher_with_multiple_roles
    }
  end
  let!(:intervention) { create(:intervention, user: user) }
  let!(:intervention_2) { create(:intervention, user: user) }
  let(:other_session) { create(:session, intervention: intervention) }
  let!(:session) do
    create(:session, intervention: intervention,
                     formula: { 'payload' => 'var + 5', 'patterns' => [
                       { 'match' => '=8', 'target' => { 'id' => other_session.id, type: 'Session' } }
                     ] },
                     settings: { 'formula' => true, 'narrator' => { 'animation' => true, 'voice' => true } })
  end
  let!(:question_group) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
  let!(:questions) { create_list(:question_single, 3, question_group: question_group) }
  let!(:params) do
    {
      new_intervention_id: intervention_2.id
    }
  end
  let!(:headers) { user.create_new_auth_token }
  let(:request) { post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let!(:request) { post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'when there are sms plans' do
      %w[researcher researcher_with_multiple_roles].each do |role|
        let(:user) { users[role] }
        context 'is valid' do
          before { request }

          it_behaves_like 'authorized user'

          it 'session is duplicated' do
            expect(json_response['data']['attributes']).to include(
              'intervention_id' => intervention_2.id,
              'position' => intervention_2.sessions.size,
              'name' => session.name,
              'schedule' => session.schedule,
              'schedule_payload' => session.schedule_payload,
              'variable' => "duplicated_#{session.variable}_#{intervention_2.sessions.last&.position.to_i}"
            )
          end

          it 'question_group is duplicated' do
            expect(Session.find(json_response['data']['id']).question_groups.first).not_to eq(nil)
          end

          it 'question_group duplicated has diffrent id from original' do
            expect(Session.find(json_response['data']['id']).question_groups.first.title).to eq(question_group.title)
          end

          it 'questions are duplicated' do
            expect(Session.find(json_response['data']['id']).question_groups.first.questions.size).to eq(3)
          end

          it 'question duplicated has diffrent id from original' do
            expect(Session.find(json_response['data']['id']).question_groups.first.questions.first.title).to eq(questions.first.title)
          end
        end
      end
    end
  end

  context 'when intervention_id is invalid' do
    before do
      post v1_intervention_duplicate_session_path(intervention_id: 9000, id: session.id), params: params, headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when session_id is invalid' do
    before do
      post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: 9000), params: params, headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when params are invalid' do
    let(:params) do
      {
        new_intervention_id: 9999
      }
    end

    before do
      post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers
    end

    it 'error message is expected' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when all params are valid and response' do
    context 'is success' do
      before do
        post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:created) }

      it 'session is duplicated' do
        expect(json_response['data']['attributes']).to include(
          'intervention_id' => intervention_2.id,
          'position' => intervention_2.sessions.size,
          'name' => session.name,
          'schedule' => session.schedule,
          'schedule_payload' => session.schedule_payload
        )
      end

      it 'has cleared formula' do
        expect(json_response['data']['attributes']['formula']).to include(
          'payload' => '',
          'patterns' => []
        )
        expect(json_response['data']['attributes']['settings']['formula']).to eq(false)
      end

      it 'question_group is duplicated' do
        expect(Session.find(json_response['data']['id']).question_groups.first).not_to eq(nil)
      end

      it 'question_group duplicated has diffrent id from original' do
        expect(Session.find(json_response['data']['id']).question_groups.first.title).to eq(question_group.title)
      end

      it 'questions are duplicated' do
        expect(Session.find(json_response['data']['id']).question_groups.first.questions.size).to eq(3)
      end

      it 'question duplicated has diffrent id from original' do
        expect(Session.find(json_response['data']['id']).question_groups.first.questions.first.title).to eq(questions.first.title)
      end
    end
  end
end
