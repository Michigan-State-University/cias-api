# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/problems/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:problem) { create(:problem) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { post clone_v1_problem_path(id: problem.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post clone_v1_problem_path(id: problem.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        post clone_v1_problem_path(id: problem.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post clone_v1_problem_path(id: problem.id), headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        post clone_v1_problem_path(id: problem.id), headers: headers
      end

      it { expect(response).to have_http_status(:created) }
      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        post clone_v1_problem_path(id: problem.id), headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end
  end

  context 'cloned' do
    before do
      post clone_v1_problem_path(id: problem.id), headers: headers
    end
    let(:problem_was) do
      problem.attributes.except('id', 'created_at', 'updated_at')
    end
    let(:problem_cloned) do
      json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'interventions')
    end

    it 'origin and outcome same' do
      expect(problem_was).to eq(problem_cloned)
    end
  end
end
