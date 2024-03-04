# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_clinics/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) do
    create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health')
  end
  let!(:organization2) do
    create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Other Organization')
  end
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:deleted_health_clinic) { create(:health_clinic, name: 'Deleted Health Clinic', health_system: health_system, deleted_at: Time.current) }
  let!(:health_clinic_admin) { health_clinic.user_health_clinics.first.user }
  let!(:health_clinic_invitation) { health_clinic_admin.health_clinic_invitations.first }

  let(:roles_organization) do
    {
      'organization_admin' => organization.organization_admins.first,
      'e_intervention_admin' => organization.e_intervention_admins.first,
      'health_clinic_admin' => health_clinic_admin
    }
  end

  let(:roles_organization2) do
    {
      'organization_admin' => organization2.organization_admins.first,
      'e_intervention_admin' => organization2.e_intervention_admins.first
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_health_clinic_path(health_clinic.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_health_clinic_path(health_clinic.id) }

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
            'id' => health_clinic.id.to_s,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic.name,
              'deleted' => false
            },
            'relationships' => {
              'health_clinic_admins' => {
                'data' => [include('id' => health_clinic_admin.id)]
              },
              'health_clinic_invitations' => {
                'data' => [include('id' => health_clinic_invitation.id)]
              }
            }
          }
        )
      end

      it 'returns proper include for health_clinic_admin' do
        expect(json_response['included'][0]['attributes']).to include(
          {
            'email' => health_clinic_admin.email,
            'first_name' => health_clinic_admin.first_name,
            'last_name' => health_clinic_admin.last_name,
            'roles' => ['health_clinic_admin']
          }
        )
      end

      it 'returns proper include for health_clinic_invitation' do
        expect(json_response['included'][1]['attributes']).to include(
          {
            'organizable_id' => health_clinic.id,
            'user_id' => health_clinic_admin.id,
            'is_accepted' => true
          }
        )
      end

      it 'returns proper collection size' do
        expect(json_response.size).to eq(2)
      end
    end

    shared_examples 'permitted behavior with a deleted clinic' do
      let(:request) { get v1_health_clinic_path(deleted_health_clinic.id), headers: headers, params: params }
      before { request }

      context 'with flag' do
        let(:params) do
          {
            with_deleted: true
          }
        end

        it 'return correct data' do
          expect(json_response['data']).to include(
            {
              'id' => deleted_health_clinic.id.to_s,
              'type' => 'health_clinic',
              'attributes' => {
                'health_system_id' => health_system.id,
                'name' => deleted_health_clinic.name,
                'deleted' => true
              },
              'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
            }
          )
        end
      end

      context 'without flag' do
        let(:request) { get v1_health_clinic_path(deleted_health_clinic.id), headers: headers }

        it 'return error message' do
          expect(json_response['message']).to include('Couldn\'t find HealthClinic with')
        end
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when admin has multiple roles' do
      let(:user) { create(:user, :confirmed, :admin) }

      it_behaves_like 'permitted user'
    end

    context 'when user is' do
      %w[organization_admin e_intervention_admin health_clinic_admin].each do |role|
        context role.to_s do
          context 'refers to their health_system' do
            let(:user) { roles_organization[role] }

            it_behaves_like 'permitted user'
          end
        end
      end

      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          context 'refers to their health_system' do
            let(:user) { roles_organization[role] }

            it_behaves_like 'permitted behavior with a deleted clinic'
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

    %i[health_system_admin team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is' do
      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          let(:user) { roles_organization2[role] }

          before { request }

          it 'returns proper error message' do
            expect(json_response['message']).to include('Couldn\'t find HealthClinic with')
          end
        end
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
