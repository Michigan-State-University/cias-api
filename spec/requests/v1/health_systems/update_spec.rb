# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/health_systems/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) do
    create(:health_system, :with_health_system_admin, name: 'Health System 1', organization: organization)
  end
  let!(:new_health_system_admin) { create(:user, :confirmed, :health_system_admin) }
  let!(:health_system_admin_to_remove) { health_system.health_system_admins.first }
  let(:admins_ids) { health_system.reload.health_system_admins.pluck(:id) }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      health_system: {
        name: 'Health System 50',
        health_system_admins_to_remove: [health_system_admin_to_remove.id],
        health_system_admins_to_add: [new_health_system_admin.id]
      }
    }
  end
  let(:request) { patch v1_health_system_path(health_system.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_health_system_path(health_system.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns correct status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns proper data' do
        expect(json_response['data']).to include(
          {
            'id' => health_system.id,
            'type' => 'health_system',
            'attributes' => {
              'name' => 'Health System 50',
              'organization_id' => organization.id
            },
            'relationships' => {
              'health_system_admins' => { 'data' => [{ 'id' => new_health_system_admin.id, 'type' => 'user' }] },
              'health_clinics' => { 'data' => [] }
            }
          }
        )
      end
    end

    context 'when user is admin' do
      context 'when params are proper' do
        it_behaves_like 'permitted user'
      end

      context 'when params are invalid' do
        let(:params) do
          {
            health_system: {
              name: nil
            }
          }

          it { expect(response).to have_http_status(:unprocessable_entity) }

          it 'response contains proper error message' do
            expect(json_response['message']).to eq "Validation failed: Name can't be blank"
          end
        end
      end
    end

    context 'when user is e_intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'permitted user'
    end

    context 'when user has multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[participant admin guest]) }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[health_system_admin organization_admin team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
