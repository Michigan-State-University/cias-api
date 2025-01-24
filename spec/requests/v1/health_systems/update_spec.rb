# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/health_systems/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:user) { admin }

  let(:roles) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles,
      'e_intervention_admin' => organization.e_intervention_admins.first
    }
  end

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, :with_health_system_admin, name: 'Health System 1', organization: organization) }
  let!(:deleted_health_system) { create(:health_system, name: 'Deleted Health System', organization: organization, deleted_at: Time.current) }
  let!(:health_system_admin) { health_system.health_system_admins.first }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      health_system: {
        name: 'Health System 50'
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
              'organization_id' => organization.id,
              'deleted' => false
            },
            'relationships' => {
              'health_system_admins' => { 'data' => [{ 'id' => health_system_admin.id, 'type' => 'user' }] },
              'health_clinics' => { 'data' => [] }
            }
          }
        )
      end

      context 'when health system is deleted' do
        let(:request) { patch v1_health_system_path(deleted_health_system.id), params: params, headers: headers }

        it 'return error message' do
          expect(json_response['message']).to include('Couldn\'t find HealthSystem with')
        end

        context 'with flag' do
          let(:params) do
            {
              health_system: {
                name: 'Health System 50'
              },
              with_deleted: true
            }
          end

          it 'return forbidden status' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end

      context 'when params are invalid', skip: 'behaviour not implemented' do
        let(:params) do
          {
            health_system: {
              name: ''
            }
          }
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq "Validation failed: Name can't be blank"
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      context "when user is #{role}" do
        let(:user) { roles[role] }

        it_behaves_like 'permitted user'
      end
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[health_system_admin health_clinic_admin organization_admin team_admin researcher participant guest third_party].each do |role|
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
