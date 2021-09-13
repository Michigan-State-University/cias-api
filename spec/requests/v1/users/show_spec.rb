# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:alter_user) { create(:user, :confirmed, :participant) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_user_path(id: alter_user.id), headers: headers }
  let(:users) do
    {
      'admin' => admin,
      'user_with_multiple_roles' => user_with_multiple_roles
    }
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_user_path(id: alter_user.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when response' do
    %w[admin user_with_multiple_roles].each do |role|
      let(:user) { users[role] }
      context 'is JSON' do
        before { request }

        it 'return User' do
          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          expect(json_response.class).to be(Hash)
          expect(json_response['data']['attributes']['email']).to eq(alter_user.email)
        end
      end
    end
  end

  context 'when user is e-intervention admin' do
    let_it_be(:organization) { create(:organization, name: 'Awesome Organization') }
    let_it_be(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
    let(:alter_user) { health_system.health_system_admins.first }
    let(:current_user) { create(:user, :confirmed, :e_intervention_admin, first_name: 'John', last_name: 'E-intervention admin', email: 'john.e_intervention_admin@test.com', created_at: 5.days.ago, organizable: organization) }

    before { request }

    it 'return user' do
      expect(json_response['data']['attributes']['email']).to eq(alter_user.email)
    end
  end

  context 'invalid id' do
    before do
      get v1_user_path(id: 'invalid'), headers: headers
    end

    it 'returns not found' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
