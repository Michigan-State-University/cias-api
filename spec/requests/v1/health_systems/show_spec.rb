# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_systems/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[admin participant]) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:user) { admin }

  let!(:organization) do
    create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health')
  end
  let!(:health_system) { create(:health_system, :with_health_system_admin, :with_health_clinic, organization: organization) }
  let!(:deleted_health_system) { create(:health_system, organization: organization, name: 'Deleted health system', deleted_at: Time.current) }
  let!(:health_clinic) { health_system.health_clinics.first }

  let!(:organization1) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Oregano Public Health') }
  let!(:health_system1) { create(:health_system, :with_health_system_admin, :with_health_clinic, organization: organization1, name: 'Test') }

  let!(:health_system_admin) { health_system.health_system_admins.first }
  let!(:health_system_admin1) { health_system1.health_system_admins.first }

  let(:admins) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end

  let(:roles_organization) do
    {
      'organization_admin' => organization.organization_admins.first,
      'e_intervention_admin' => organization.e_intervention_admins.first,
      'health_system_admin' => health_system_admin
    }
  end
  let(:roles_organization1) do
    {
      'organization_admin' => organization1.organization_admins.first,
      'e_intervention_admin' => organization1.e_intervention_admins.first,
      'health_system_admin' => health_system_admin1
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_health_system_path(health_system.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_health_system_path(health_system.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper data' do
        expect(json_response['data']).to include(
          {
            'id' => health_system.id.to_s,
            'type' => 'health_system',
            'attributes' => {
              'name' => health_system.name,
              'organization_id' => organization.id,
              'deleted' => false
            },
            'relationships' => {
              'health_system_admins' => {
                'data' => [{ 'id' => health_system_admin.id, 'type' => 'user' }]
              },
              'health_clinics' => {
                'data' => [{ 'id' => health_clinic.id, 'type' => 'health_clinic' }]
              }
            }
          }
        )
      end

      it 'returns proper include' do
        expect(json_response['included']).to include(
          {
            'id' => health_clinic.id,
            'type' => 'health_clinic',
            'attributes' => {
              'name' => health_clinic.name,
              'health_system_id' => health_clinic.health_system_id,
              'deleted' => false
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
          }
        ).and include(
          {
            'id' => health_system_admin.id,
            'type' => 'user',
            'attributes' =>
              include(
                'email' => health_system_admin.email,
                'roles' => ['health_system_admin'],
                'first_name' => health_system_admin.first_name,
                'last_name' => health_system_admin.last_name
              )
          }
        )
      end

      it 'returns proper collection size' do
        expect(json_response.size).to eq(2)
      end

      context 'when clinic is deleted' do
        let(:request) { get v1_health_system_path(deleted_health_system.id), headers: headers }

        it 'without flag' do
          expect(json_response['message']).to include('Couldn\'t find HealthSystem with')
        end

        context 'with flat' do
          let(:params) do
            {
              with_deleted: true
            }

            it 'return health system' do
              expect(json_response['data']).to include(
                {
                  'id' => deleted_health_system.id.to_s,
                  'type' => 'health_system',
                  'attributes' => {
                    'name' => deleted_health_system.name,
                    'organization_id' => organization.id,
                    'deleted' => false
                  },
                  'relationships' => {
                    'health_system_admins' => {
                      'data' => []
                    },
                    'health_clinics' => {
                      'data' => []
                    }
                  }
                }
              )
            end
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      context "when user is #{role}" do
        let(:user) { admins[role] }

        it_behaves_like 'permitted user'
      end
    end

    %w[organization_admin e_intervention_admin health_system_admin].each do |role|
      context "when user is #{role}" do
        context 'refers to their health_system' do
          let(:user) { roles_organization[role] }

          it_behaves_like 'permitted user'
        end

        context 'doesn\'t refer to other health_system' do
          let(:user) { roles_organization1[role] }

          before { request }

          it 'returns proper error message' do
            expect(json_response['message']).to include('Couldn\'t find HealthSystem with')
          end
        end
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

    %i[health_clinic_admin team_admin researcher participant guest third_party].each do |role|
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
