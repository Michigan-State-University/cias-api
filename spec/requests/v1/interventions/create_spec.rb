# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params) do
    {
      intervention: {
        type: 'Intervention::Single',
        name: 'research_assistant test1',
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

  context 'when endpoint is available' do
    before { post v1_interventions_path }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post v1_interventions_path, params: params
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')

        post v1_interventions_path, params: params, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post v1_interventions_path, params: params, headers: headers
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
        post v1_interventions_path, params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { intervention: {} }
          post v1_interventions_path, params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
