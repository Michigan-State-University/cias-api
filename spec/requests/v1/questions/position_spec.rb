# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/interventions/:intervention_id/questions/position', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:question_1) { create(:question_analogue_scale, intervention_id: intervention.id) }
  let(:question_2) { create(:question_bar_graph, intervention_id: intervention.id) }
  let(:question_3) { create(:question_information, intervention_id: intervention.id) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params) do
    {
      question: {
        position: [
          {
            id: question_1.id,
            position: 11
          },
          {
            id: question_2.id,
            position: 22
          },
          {
            id: question_3.id,
            position: 33
          }
        ]
      }
    }
  end

  context 'when endpoint is available' do
    before { patch v1_intervention_questions_position_path(intervention_id: intervention.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        patch v1_intervention_questions_position_path(intervention_id: intervention.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        patch v1_intervention_questions_position_path(intervention_id: intervention.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        patch v1_intervention_questions_position_path(intervention_id: intervention.id), params: params, headers: headers
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
        patch v1_intervention_questions_position_path(intervention_id: intervention.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        patch v1_intervention_questions_position_path(intervention_id: intervention.id), params: params, headers: headers
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key question' do
        expect(json_response['data'].first['type']).to eq('question')
      end
    end
  end
end
