# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/sessions', type: :request do
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
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_intervention_sessions_path(intervention.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_intervention_sessions_path(intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'one or multiple roles' do
    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }
      context 'when response' do
        context 'is JSON' do
          before { request }

          it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
        end

        context 'is JSON and parse' do
          before { request }

          it 'success to Hash' do
            expect(json_response.class).to be(Hash)
          end
        end
      end
    end
  end
end
