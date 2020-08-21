# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/questions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:question) { create(:question_analogue_scale, intervention_id: intervention.id) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when response' do
    context 'is success' do
      before do
        delete v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:ok) }
    end
  end
end
