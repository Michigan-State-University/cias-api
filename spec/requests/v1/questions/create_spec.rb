# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/questions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention_single) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params) do
    {
      question: {
        type: 'Question::Multiple',
        order: nil,
        title: 'Question Test 1',
        subtitle: 'test 1',
        formula: {
          payload: 'test',
          patterns: [
            {
              match: '= 5',
              target: '1'
            },
            {
              match: '> 5',
              target: '7'
            }
          ]
        },
        body: {
          data: [
            {
              payload: 'create1',
              variable: {
                name: 'test1',
                value: '1'
              }
            },
            {
              payload: 'create2',
              variable: {
                name: 'test2',
                value: '2'
              }
            }
          ]
        }
      }
    }
  end

  context 'when endpoint is available' do
    before { post v1_intervention_questions_path(intervention.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post v1_intervention_questions_path(intervention.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        post v1_intervention_questions_path(intervention.id), params: params, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post v1_intervention_questions_path(intervention.id), params: params, headers: headers
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
        post v1_intervention_questions_path(intervention.id), params: params, headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        post v1_intervention_questions_path(intervention.id), params: params, headers: headers
      end

      it 'success to Hash' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.class).to be(Hash)
      end
    end
  end
end
