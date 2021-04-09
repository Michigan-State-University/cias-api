# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/sessions/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let!(:sms_plan) { create(:sms_plan, session: session) }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_intervention_session_path(intervention_id: intervention.id, id: session.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_intervention_session_path(intervention_id: intervention.id, id: session.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    context 'is JSON' do
      before { request }

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before { request }

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key session' do
        expect(json_response['data']['type']).to eq('session')
      end

      it 'key sms_plans_count' do
        expect(json_response['data']['attributes']['sms_plans_count']).to eq 1
      end
    end
  end
end
