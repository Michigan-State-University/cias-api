# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/problems/:id/answers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:problem) { create(:problem) }
  let(:interventions) { create_list(:intervention, 2, problem_id: problem.id) }
  let(:questions) { create_list(:question_single, 4, intervention_id: intervention.id) }
  let(:answers) { create_list(:intervention, 6, question_id: question.id) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { get v1_problem_answers_path(problem.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        get v1_problem_answers_path(problem.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get v1_problem_answers_path(problem.id), params: {}, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get v1_problem_answers_path(problem.id), params: {}, headers: headers
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
        get v1_problem_answers_path(problem.id), params: {}, headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_problem_answers_path(problem.id), params: {}, headers: headers
      end

      let(:parsed_response) { JSON.parse(response.body) }

      it 'success to Hash' do
        expect(parsed_response.class).to be(Hash)
      end

      it 'success message' do
        expect(json_response['message']).to eq 'The request to send the CSV file has been successfully created. We will soon send a CSV file to your email address.'
      end
    end
  end
end
