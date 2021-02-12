# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:id/answers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:sessions) { create_list(:session, 2, intervention_id: intervention.id) }
  let(:questions) { create_list(:question_single, 4, session_id: session.id) }
  let(:answers) { create_list(:session, 6, question_id: question.id) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_intervention_answers_path(intervention.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_intervention_answers_path(intervention.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_intervention_answers_path(intervention.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_intervention_answers_path(intervention.id), headers: headers
      end

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
