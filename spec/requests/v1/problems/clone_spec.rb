# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/problems/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:problem) { create(:problem) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { post clone_v1_problem_path(id: problem.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post clone_v1_problem_path(id: problem.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
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
      expect(problem_was.delete(['status'])).to eq(problem_cloned.delete(['status']))
    end

    it 'status to draft' do
      expect(problem_cloned['status']).to eq('draft')
    end
  end
end
