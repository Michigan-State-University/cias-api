# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:intervention) { create(:intervention, :slug) }
  let(:params) do
    {
      intervention: {
        name: 'test1 params',
        body: {
          payload: 1,
          target: '',
          variable: '1'
        }
      }
    }
  end

  context 'when endpoint is available' do
    before { patch v1_intervention_path(intervention.slug) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        patch v1_intervention_path(intervention.slug), params: params
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')

        patch v1_intervention_path(intervention.slug), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        intervention.reload
        patch v1_intervention_path(intervention.slug), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when params' do
    context 'valid' do
      before do
        intervention.reload
        patch v1_intervention_path(intervention.slug), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { intervention: {} }
          intervention.reload
          patch v1_intervention_path(intervention.slug), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
