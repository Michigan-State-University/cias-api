# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { post v1_clone_intervention_path(id: intervention.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_clone_intervention_path(id: intervention.id), headers: headers }

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
