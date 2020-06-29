# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/questions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:question) { create(:question_single) }
  let(:intervention) { question.intervention }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { get clone_v1_intervention_question_path(intervention_id: intervention.id, id: question.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        get clone_v1_intervention_question_path(intervention_id: intervention.id, id: question.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get clone_v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get clone_v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
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
        get clone_v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it { expect(response).to have_http_status(:created) }
      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get clone_v1_intervention_question_path(intervention_id: intervention.id, id: question.id), headers: headers
      end

      it 'success to Hash' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.class).to be(Hash)
      end
    end
  end
end
