# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) do
    create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health')
  end
  let!(:health_system) { create(:health_system, :with_clinics, organization: organization) }
  let!(:deleted_health_system) { create(:health_system, organization: organization, deleted_at: Time.current, name: 'Deleted health system') }
  let!(:deleted_health_clinic) { create(:health_clinic, health_system: deleted_health_system, deleted_at: Time.current, name: 'Deleted healt clinic') }
  let!(:health_clinic) { health_system.health_clinics.first }
  let!(:organization1) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Oregano Public Health') }

  let(:e_intervention_admin) { organization.e_intervention_admins.first }
  let(:organization_admin) { organization.organization_admins.first }

  let(:roles_organization) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin
    }
  end
  let(:roles_organization1) do
    {
      'organization_admin' => organization1.organization_admins.first,
      'e_intervention_admin' => organization1.e_intervention_admins.first
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organization_path(organization.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_organization_path(organization.id) }

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
            'id' => organization.id.to_s,
            'type' => 'organization',
            'attributes' => {
              'name' => organization.name
            },
            'relationships' =>
                {
                  'e_intervention_admins' =>
                      {
                        'data' => [{ 'id' => organization.e_intervention_admins.first.id, 'type' => 'user' }]
                      },
                  'organization_admins' =>
                        {
                          'data' => [{ 'id' => organization.organization_admins.first.id, 'type' => 'user' }]
                        },
                  'health_systems' =>
                      {
                        'data' => include(
                          { 'id' => health_system.id, 'type' => 'health_system' },
                          { 'id' => deleted_health_system.id, 'type' => 'health_system' }
                        )
                      },
                  'health_clinics' =>
                      {
                        'data' => include(
                          { 'id' => health_clinic.id, 'type' => 'health_clinic' },
                          { 'id' => deleted_health_clinic.id, 'type' => 'health_clinic' }
                        )
                      }
                }
          }
        )
      end

      it 'returns proper include' do
        expect(json_response['included'][0]).to include(
          {
            'id' => e_intervention_admin.id,
            'type' => 'user',
            'attributes' =>
                include(
                  'email' => e_intervention_admin.email,
                  'first_name' => e_intervention_admin.first_name,
                  'last_name' => e_intervention_admin.last_name,
                  'roles' => ['e_intervention_admin']
                )
          }
        )
        expect(json_response['included'][1]).to include(
          'id' => deleted_health_clinic.id,
          'type' => 'health_clinic',
          'attributes' => {
            'name' => 'Deleted healt clinic',
            'health_system_id' => deleted_health_system.id,
            'deleted' => true
          },
          'relationships' => {
            'health_clinic_admins' => {
              'data' => []
            }
          }
        )
        expect(json_response['included'][2]).to include(
          {
            'id' => health_clinic.id,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic.name,
              'deleted' => false
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] } }
          }
        )
        expect(json_response['included'][3]).to include(
          {
            'id' => deleted_health_system.id,
            'type' => 'health_system',
            'attributes' =>
              {
                'name' => deleted_health_system.name,
                'organization_id' => health_system.organization_id,
                'deleted' => true
              },
            'relationships' =>
              {
                'health_system_admins' => { 'data' => [] },
                'health_clinics' => { 'data' => [
                  {
                    'id' => deleted_health_clinic.id,
                    'type' => 'health_clinic'
                  }
                ] }
              }
          }
        )
        expect(json_response['included'][4]).to include(
          {
            'id' => health_system.id,
            'type' => 'health_system',
            'attributes' =>
                  {
                    'name' => health_system.name,
                    'organization_id' => health_system.organization_id,
                    'deleted' => false
                  },
            'relationships' =>
                  {
                    'health_system_admins' => { 'data' => [] },
                    'health_clinics' => { 'data' => [{ 'id' => health_clinic.id, 'type' => 'health_clinic' }] }
                  }
          }
        )
        expect(json_response['included'][5]).to include(
          {
            'id' => organization_admin.id,
            'type' => 'user',
            'attributes' =>
                  include(
                    'email' => organization_admin.email,
                    'first_name' => organization_admin.first_name,
                    'last_name' => organization_admin.last_name,
                    'roles' => ['organization_admin']
                  )
          }
        )
      end

      it 'returns proper collection size' do
        expect(json_response.size).to eq(2)
      end
    end

    context 'when user is' do
      %w[admin admin_with_multiple_roles].each do |role|
        context role.to_s do
          let(:user) { users[role] }

          it_behaves_like 'permitted user'
        end
      end

      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          context 'refers to their organization' do
            let(:user) { roles_organization[role] }

            it_behaves_like 'permitted user'
          end

          context 'doesn\'t refer to other organization' do
            let(:user) { roles_organization1[role] }

            before { request }

            it 'returns proper error message' do
              expect(json_response['message']).to include('Couldn\'t find Organization with')
            end
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

    %i[team_admin researcher participant guest].each do |role|
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
