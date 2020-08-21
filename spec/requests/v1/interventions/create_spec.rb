# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/problems/:problem_id/interventions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:problem) { create(:problem) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params) do
    {
      intervention: {
        name: 'research_assistant test1',
        problem_id: problem.id,
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
    before { post v1_problem_interventions_path(problem_id: problem.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post v1_problem_interventions_path(problem_id: problem.id), params: params
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')

        post v1_problem_interventions_path(problem_id: problem.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post v1_problem_interventions_path(problem_id: problem.id), params: params, headers: headers
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
        post v1_problem_interventions_path(problem_id: problem.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { intervention: {} }
          post v1_problem_interventions_path(problem_id: problem.id), params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
