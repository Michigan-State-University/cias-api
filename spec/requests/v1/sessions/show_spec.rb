# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/sessions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
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

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
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

          it 'keys responsible for autofinish with default value' do
            expect(json_response['data']['attributes']['autofinish_enabled']).to eq false
            expect(json_response['data']['attributes']['autofinish_delay']).to eq 1440
          end

          it 'keys responsible for autoclose with default value' do
            expect(json_response['data']['attributes']['autoclose_enabled']).to eq false
            expect(json_response['data']['attributes']['autoclose_at']).to eq nil
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end
end
