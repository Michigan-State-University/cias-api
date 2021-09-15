# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/organizations/:id', type: :request do
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
  let!(:new_organization_admin) { create(:user, :confirmed, :organization_admin) }
  let!(:organization_admin_to_remove) { organization.organization_admins.first }
  let(:admins_ids) { organization.reload.organization_admins.pluck(:id) }
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }
  let!(:organization_admin) { organization.organization_admins.first }
  let(:e_intervention_admin_invitation) { e_intervention_admin.organization_invitations.first }

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      organization: {
        name: 'Oregano Public Health',
        organization_admins_to_remove: [organization_admin_to_remove.id],
        organization_admins_to_add: [new_organization_admin.id]
      }
    }
  end
  let(:request) { patch v1_organization_path(organization.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_organization_path(organization.id) }

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
            'id' => organization.id,
            'type' => 'organization',
            'attributes' => {
              'name' => 'Oregano Public Health',
              'e_intervention_admin_invitations' => {
                'data' => [{
                  'id' => e_intervention_admin_invitation.id,
                  'type' => 'organizable_invitation',
                  'attributes' =>
                                  include(
                                    'user_id' => e_intervention_admin_invitation.user_id,
                                    'organizable_id' => e_intervention_admin_invitation.organization_id,
                                    'is_accepted' => true
                                  )
                }]
              }
            },
            'relationships' => { 'e_intervention_admins' => { 'data' => [{ 'id' => e_intervention_admin.id, 'type' => 'user' }] },
                                 'organization_admins' => { 'data' => [{ 'id' => new_organization_admin.id,
                                                                         'type' => 'user' }] },
                                 'health_clinics' => { 'data' => [] },
                                 'health_systems' => { 'data' => [] },
                                 'organization_invitations' => { 'data' => [] } }
          }
        )
      end
    end

    context 'when user is admin' do
      context 'one or multiple roles' do
        %w[admin admin_with_multiple_roles].each do |role|
          let(:user) { users[role] }
          context 'when params are proper' do
            it_behaves_like 'permitted user'
          end

          context 'when params are invalid' do
            let(:params) do
              {
                organization: {
                  name: ''
                }
              }

              it { expect(response).to have_http_status(:unprocessable_entity) }

              it 'response contains proper error message' do
                expect(json_response['message']).to eq "Validation failed: Name can't be blank"
              end
            end
          end
        end
      end
    end

    context 'when user is e_intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'permitted user'
    end

    context 'organization with health system' do
      let!(:health_system) { create(:health_system, organization: organization) }
      let(:params) do
        {
          organization: {
            name: 'Oregano Public Health'
          }
        }
      end

      before { request }

      it 'include organization structure' do
        expect(json_response['included']).to include({
                                                       'id' => health_system.id,
                                                       'type' => 'health_system',
                                                       'attributes' => {
                                                         'name' => health_system.name,
                                                         'organization_id' => organization.id,
                                                         'deleted' => false
                                                       },
                                                       'relationships' => {
                                                         'health_clinics' => {
                                                           'data' => []
                                                         },
                                                         'health_system_admins' => {
                                                           'data' => []
                                                         }
                                                       }
                                                     })
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
