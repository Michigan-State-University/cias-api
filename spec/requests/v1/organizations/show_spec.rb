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

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_clinics, organization: organization) }
  let!(:health_clinic) { health_system.health_clinics.first }
  let!(:organization_1) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Oregano Public Health') }

  let(:e_intervention_admin) { organization.e_intervention_admins.first }
  let(:organization_admin) { organization.organization_admins.first }

  let(:roles_organization) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin
    }
  end
  let(:roles_organization_1) do
    {
      'organization_admin' => organization_1.organization_admins.first,
      'e_intervention_admin' => organization_1.e_intervention_admins.first
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
              'name' => organization.name,
              'health_systems_and_clinics' => {
                'data' => [
                  {
                    'attributes' => {
                      'health_clinics' => {
                        'data' => [
                          {
                            'attributes' => {
                              'health_system_id' => health_system.id,
                              'name' => health_clinic.name
                            },
                            'id' => health_clinic.id,
                            'type' => 'health_clinic'
                          }
                        ]
                      },
                      'name' => health_system.name,
                      'organization_id' => health_system.organization_id
                    },
                    'id' => health_system.id,
                    'type' => 'health_system',
                    'relationships' => { 'health_system_admins' => { 'data' => [] } }
                  }
                ]
              }
            },
            'relationships' =>
                {
                  'e_intervention_admins' =>
                      {
                        'data' =>
                              [
                                { 'id' => organization.e_intervention_admins.first.id, 'type' => 'e_intervention_admin' }
                              ]
                      },
                  'organization_admins' =>
                        {
                          'data' =>
                              [
                                { 'id' => organization.organization_admins.first.id, 'type' => 'organization_admin' }
                              ]
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

    context 'when user is admin' do
      context 'one or multiple roles' do
        %w[admin admin_with_multiple_roles].each do |role|
          let(:user) { users[role] }

          it_behaves_like 'permitted user'
        end
      end
    end

    context 'when user is' do
      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          context 'refers to their organization' do
            let(:user) { roles_organization[role] }

            it_behaves_like 'permitted user'
          end

          context 'doesn\'t refer to other organization' do
            let(:user) { roles_organization_1[role] }

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
