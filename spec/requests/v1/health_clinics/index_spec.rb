# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_clinics', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
  let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
  let!(:health_clinic1) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
  let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }
  let!(:deleted_health_clinic) { create(:health_clinic, name: 'Deleted Health Clinic', health_system: health_system, deleted_at: Time.current) }

  let(:roles) do
    {
      'organization_admin' => organization.organization_admins.first,
      'e_intervention_admin' => organization.e_intervention_admins.first
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_health_clinics_path, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_health_clinics_path }

      it_behaves_like 'unauthorized user'
    end
  end

  context 'is valid' do
    it_behaves_like 'authorized user'
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'return proper collection size' do
        expect(json_response['data'].size).to eq(2)
      end

      it 'return proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => health_clinic1.id.to_s,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic1.name,
              'deleted' => false
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
          },
          {
            'id' => health_clinic2.id.to_s,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic2.name,
              'deleted' => false
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
          }
        )
      end

      context 'with deleted clinic' do
        let(:params) do
          {
            with_deleted: true
          }
        end
        let(:request) { get v1_health_clinics_path, headers: headers, params: params }

        before { request }

        it 'return proper collection size' do
          expect(json_response['data'].size).to eq(3)
        end

        it 'return proper collection data' do
          expect(json_response['data']).to include(
            {
              'id' => health_clinic1.id.to_s,
              'type' => 'health_clinic',
              'attributes' => {
                'health_system_id' => health_system.id,
                'name' => health_clinic1.name,
                'deleted' => false
              },
              'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
            },
            {
              'id' => health_clinic2.id.to_s,
              'type' => 'health_clinic',
              'attributes' => {
                'health_system_id' => health_system.id,
                'name' => health_clinic2.name,
                'deleted' => false
              },
              'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
            },
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
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when admin has multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[guest admin]) }

      it_behaves_like 'permitted user'
    end

    context 'when user is' do
      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          let(:user) { roles[role] }

          before { request }

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

      %i[health_system_admin team_admin researcher participant guest].each do |role|
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

  context 'when user is health_clinic_admin' do
    let!(:health_clinic1) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic 1', health_system: health_system) }
    let!(:health_clinic2) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic 2', health_system: health_system) }
    let!(:health_clinic3) { create(:health_clinic, name: 'Health Clinic 3', health_system: health_system) }
    let(:user) { health_clinic1.user_health_clinics.first.user }
    let(:health_clinic1_invitation) { health_clinic1.health_clinic_invitations.first }

    context 'when health clinics have different clinic admins' do
      before { request }

      it 'returns correct health clinic size' do
        expect(json_response['data'].size).to eq(1)
      end

      it 'return proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => health_clinic1.id.to_s,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic1.name,
              'deleted' => false
            },
            'relationships' => {
              'health_clinic_admins' => { 'data' => [include({ 'id' => user.id })] },
              'health_clinic_invitations' => { 'data' => [include({ 'id' => health_clinic1_invitation.id })] }
            }
          }
        ).and not_include({
                            'id' => health_clinic2.id.to_s,
                            'type' => 'health_clinic',
                            'attributes' => {
                              'health_system_id' => health_system.id,
                              'name' => health_clinic2.name
                            }
                          })
      end
    end

    context 'when user did not accepted invitation to other clinic' do
      before do
        health_clinic3.user_health_clinics << UserHealthClinic.create!(user: user, health_clinic: health_clinic3)
        HealthClinicInvitation.create!(user: user, health_clinic: health_clinic3)
        request
      end

      it 'returns correct health clinic size' do
        expect(json_response['data'].size).to eq(1)
      end

      it 'return proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => health_clinic1.id.to_s,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic1.name,
              'deleted' => false
            },
            'relationships' => {
              'health_clinic_admins' => { 'data' => [include({ 'id' => user.id })] },
              'health_clinic_invitations' => { 'data' => [include({ 'id' => health_clinic1_invitation.id })] }
            }
          }
        ).and not_include({
                            'id' => health_clinic3.id.to_s,
                            'type' => 'health_clinic',
                            'attributes' => {
                              'health_system_id' => health_system.id,
                              'name' => health_clinic3.name
                            }
                          })
      end
    end
  end
end
