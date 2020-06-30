# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:intervention) { create(:intervention_single) }
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
    before { patch v1_intervention_path(intervention) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        patch v1_intervention_path(intervention), params: params
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')

        patch v1_intervention_path(intervention), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        patch v1_intervention_path(intervention), params: params, headers: headers
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
        patch v1_intervention_path(intervention), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { intervention: {} }
          patch v1_intervention_path(intervention), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'whitelist intervention type correctly' do
        before do
          invalid_params = { intervention: { type: 'test' } }
          patch v1_intervention_path(intervention), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:ok) }

        it 'before and after request, type is the same ' do
          outcome_type = JSON.parse(response.body)['data']['attributes']['type']

          expect(outcome_type).to eq(intervention.type)
        end
      end
    end
  end
end
