# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:id/answers', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: intervention_owner) }
  let(:sessions) { create_list(:session, 2, intervention_id: intervention.id) }
  let(:questions) { create_list(:question_single, 4, session_id: session.id) }
  let(:answers) { create_list(:session, 6, question_id: question.id) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_intervention_answers_path(intervention.id), headers: headers }
  let(:intervention_owner) { admin }
  let(:user) { admin }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_intervention_answers_path(intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when admin access researcher intervention csv' do
    before { request }

    let(:intervention_owner) { researcher }

    it 'returns forbidden status' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before { request }

      let(:parsed_response) { JSON.parse(response.body) }

      it 'success to Hash' do
        expect(parsed_response.class).to be(Hash)
      end

      it 'success message' do
        expect(json_response['message']).to eq 'The request to send the CSV file has been successfully created. We will soon send an email to you with the request status.'
      end
    end
  end
end
