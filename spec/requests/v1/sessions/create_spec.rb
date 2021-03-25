# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/sessions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      session: {
        name: 'research_assistant test1',
        intervention_id: intervention.id,
        body: {
          data: [
            {
              payload: 1,
              target: '',
              variable: '1'
            }
          ]
        }
      }
    }
  end
  let(:request) { post v1_intervention_sessions_path(intervention_id: intervention.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_intervention_sessions_path(intervention_id: intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when params' do
    context 'valid' do
      before { request }

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          post v1_intervention_sessions_path(intervention_id: intervention.id), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
