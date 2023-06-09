# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_systems', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:user) { admin }

  let!(:organization) do
    create(:organization, :with_health_system, :with_organization_admin, :with_e_intervention_admin)
  end
  let!(:health_system) { organization.health_systems.first }
  let!(:health_system2) { create(:health_system, :with_health_system_admin, name: 'Health System 2') }
  let!(:deleted_health_system) { create(:health_system, name: 'Deleted Health System', deleted_at: Time.current) }
  let!(:organization2) { health_system2.organization }
  let!(:health_clinic) { create(:health_clinic) }
  let!(:health_system3) { health_clinic.health_system }

  let!(:health_system_admin) { health_system2.health_system_admins.first }

  let(:roles) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles,
      'organization_admin' => organization.organization_admins.first,
      'e_intervention_admin' => organization.e_intervention_admins.first,
      'health_system_admin' => health_system_admin
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_health_systems_path, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_health_systems_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns proper collection size' do
        expect(json_response['data'].size).to eq(3)
      end

      it 'returns proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => health_system.id,
            'type' => 'health_system',
            'attributes' => {
              'name' => health_system.name,
              'organization_id' => health_system.organization_id,
              'deleted' => false
            },
            'relationships' =>
                {
                  'health_system_admins' => { 'data' => [] },
                  'health_clinics' => { 'data' => [] }
                }
          },
          {
            'id' => health_system2.id.to_s,
            'type' => 'health_system',
            'attributes' => {
              'name' => health_system2.name,
              'organization_id' => health_system2.organization_id,
              'deleted' => false
            },
            'relationships' => {
              'health_system_admins' => { 'data' => [{ 'id' => health_system_admin.id, 'type' => 'user' }] },
              'health_clinics' => { 'data' => [] }
            }
          },
          {
            'id' => health_system3.id,
            'type' => 'health_system',
            'attributes' => {
              'name' => health_system3.name,
              'organization_id' => health_system3.organization_id,
              'deleted' => false
            },
            'relationships' => {
              'health_system_admins' => { 'data' => [] },
              'health_clinics' => { 'data' => [{ 'id' => health_clinic.id, 'type' => 'health_clinic' }] }
            }
          }
        )
      end

      it 'returns proper included data' do
        expect(json_response['included'][0]).to include(
          {
            'id' => health_clinic.id,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system3.id,
              'name' => health_clinic.name,
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
        let(:request) { get v1_health_systems_path, headers: headers, params: params }

        before { request }

        it 'return proper collection size' do
          expect(json_response['data'].size).to eq(4)
        end

        it 'return proper collection data' do
          expect(json_response['data']).to include(
            {
              'id' => health_system.id,
              'type' => 'health_system',
              'attributes' => {
                'name' => health_system.name,
                'organization_id' => health_system.organization_id,
                'deleted' => false
              },
              'relationships' =>
                {
                  'health_system_admins' => { 'data' => [] },
                  'health_clinics' => { 'data' => [] }
                }
            },
            {
              'id' => health_system2.id.to_s,
              'type' => 'health_system',
              'attributes' => {
                'name' => health_system2.name,
                'organization_id' => health_system2.organization_id,
                'deleted' => false
              },
              'relationships' => {
                'health_system_admins' => { 'data' => [{ 'id' => health_system_admin.id, 'type' => 'user' }] },
                'health_clinics' => { 'data' => [] }
              }
            },
            {
              'id' => health_system3.id,
              'type' => 'health_system',
              'attributes' => {
                'name' => health_system3.name,
                'organization_id' => health_system3.organization_id,
                'deleted' => false
              },
              'relationships' => {
                'health_system_admins' => { 'data' => [] },
                'health_clinics' => { 'data' => [{ 'id' => health_clinic.id, 'type' => 'health_clinic' }] }
              }
            },
            {
              'id' => deleted_health_system.id,
              'type' => 'health_system',
              'attributes' => {
                'name' => deleted_health_system.name,
                'organization_id' => deleted_health_system.organization_id,
                'deleted' => true
              },
              'relationships' => {
                'health_system_admins' => { 'data' => [] },
                'health_clinics' => { 'data' => [] }
              }
            }
          )
        end
      end
    end

    shared_examples 'permitted user with one health system' do
      before { request }

      it 'returns proper collection size' do
        expect(json_response['data'].size).to eq(1)
      end

      it 'returns proper collection data' do
        expect(json_response['data']).to include(
          {
            'id' => chosen_health_system.id.to_s,
            'type' => 'health_system',
            'attributes' => {
              'name' => chosen_health_system.name,
              'organization_id' => chosen_health_system.organization_id,
              'deleted' => false
            },
            'relationships' => {
              'health_system_admins' => { 'data' => chosen_admins_data },
              'health_clinics' => { 'data' => [] }
            }
          }
        )
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      context "when user is #{role}" do
        let(:user) { roles[role] }

        it_behaves_like 'permitted user'
      end
    end

    %w[organization_admin e_intervention_admin health_system_admin].each do |role|
      context "when user is #{role}" do
        let!(:user) { roles[role] }

        it_behaves_like 'permitted user with one health system' do
          let(:chosen_health_system) { role.eql?('health_system_admin') ? health_system2 : health_system }
          let(:chosen_admins_data) { role.eql?('health_system_admin') ? [{ 'id' => health_system_admin.id, 'type' => 'user' }] : [] }
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

    %i[team_admin researcher participant guest third_party health_clinic_admin].each do |role|
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
