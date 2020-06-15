# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/questions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_analogue_scale) }
  let(:intervention) { question.intervention }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params) do
    {
      question: {
        type: question.type,
        order: nil,
        title: 'Question Test 1',
        subtitle: 'test 1',
        body: {
          data: [
            {
              payload: 'update1',
              variable: {
                name: 'test1',
                value: '1'
              }
            }
          ]
        }
      }
    }
  end

  context 'when endpoint is available' do
    before { patch v1_intervention_question_path(intervention_id: intervention.id, id: question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        patch v1_intervention_question_path(intervention_id: intervention.id, id: question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        patch v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        patch v1_intervention_question_path(intervention_id: intervention.id, id: question.id), params: params, headers: headers
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
        patch v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        patch v1_intervention_question_path(intervention_id: intervention.id, id: question.id), params: params, headers: headers
      end

      it 'to hash success' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.class).to be(Hash)
      end

      it 'key question' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data']['type']).to eq('question')
      end
    end
  end
end
