# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/sessions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      session: {
        name: 'test1 params',
        body: {
          payload: 1,
          target: '',
          variable: '1'
        }
      }
    }
  end
  let(:request) { patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when params' do
    context 'valid' do
      before do
        session.reload
        request
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          session.reload
          patch v1_intervention_session_path(intervention_id: intervention.id, id: session.id), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
