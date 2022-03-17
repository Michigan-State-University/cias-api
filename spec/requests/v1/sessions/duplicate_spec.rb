# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/intervention/:intervention_id/sessions/:id/duplicate', type: :request do
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
  let!(:intervention2) { create(:intervention, user: user) }
  let(:other_session) { create(:session, intervention: intervention) }
  let!(:params) do
    {
      new_intervention_id: intervention2.id
    }
  end
  let!(:headers) { user.create_new_auth_token }
  let(:request) do
    post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params,
                                                                                                   headers: headers
  end

  context 'Session::Classic' do
    let!(:session) do
      create(:session, intervention: intervention,
                       formula: { 'payload' => 'var + 5', 'patterns' => [
                         { 'match' => '=8', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
                       ] },
                       settings: { 'formula' => true, 'narrator' => { 'animation' => true, 'voice' => true } })
    end
    let!(:question_group) { create(:question_group, title: 'Question Group Title 1', session: session, position: 1) }
    let!(:questions) { create_list(:question_single, 3, question_group: question_group) }

    context 'when there are sms plans' do
      shared_examples 'permitted user' do
        context 'is valid' do
          before { request }

          it_behaves_like 'authorized user'
        end
      end
    end

    context 'when intervention_id is invalid' do
      before do
        post v1_intervention_duplicate_session_path(intervention_id: 9000, id: session.id), params: params,
                                                                                            headers: headers
      end

      it 'error message is expected' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when session_id is invalid' do
      before do
        post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: 9000), params: params,
                                                                                                 headers: headers
      end

    it 'error message is expected' do
      expect(response).to have_http_status(:ok)
    end

    context 'when params are invalid' do
      let(:params) do
        {
          new_intervention_id: 9999
        }
      end

      it 'error message is expected' do
        expect(response).to have_http_status(:ok)
      end
  end

      it 'error message is expected' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when all params are valid and response' do
      context 'is success' do
        before do
          post v1_intervention_duplicate_session_path(intervention_id: intervention.id, id: session.id), params: params,
                                                                                                         headers: headers
        end

    it 'error message is expected' do
      expect(response).to have_http_status(:ok)
    end
  end

        it 'session is duplicated' do
          expect(json_response['data']['attributes']).to include(
            'intervention_id' => intervention2.id,
            'position' => intervention2.sessions.size,
            'name' => session.name,
            'schedule' => session.schedule,
            'schedule_payload' => session.schedule_payload
          )
        end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end
