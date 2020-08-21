# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention) }
  let(:headers) do
    user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { post v1_clone_intervention_path(id: intervention.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        post v1_clone_intervention_path(id: intervention.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        post v1_clone_intervention_path(id: intervention.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        post v1_clone_intervention_path(id: intervention.id), headers: headers
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
        post v1_clone_intervention_path(id: intervention.id), headers: headers
      end

      it { expect(response).to have_http_status(:created) }
      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        post v1_clone_intervention_path(id: intervention.id), headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end
  end

  context 'cloned' do
    before do
      post v1_clone_intervention_path(id: intervention.id), headers: headers
    end

    let(:intervention_was) do
      intervention.attributes.except('id', 'created_at', 'updated_at', 'slug')
    end
    let(:intervention_cloned) do
      json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'slug')
    end

    it 'origin and outcome same' do
      expect(intervention_was).to eq(intervention_cloned)
    end
  end
end
