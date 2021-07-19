# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organizations', type: :request do
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

  let!(:organization1) { create(:organization, name: 'organization_1', created_at: DateTime.now - 10.days) }
  let!(:health_system) { create(:health_system, name: 'Vatican Healthcare', organization: organization1) }
  let!(:health_clinic) { create(:health_clinic, name: 'Best Health Clinic', health_system: health_system) }
  let!(:organization2) do
    create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health', created_at: DateTime.now - 5.days)
  end
  let!(:organization3) { create(:organization, name: 'Oregano Public Health', created_at: DateTime.now - 1.day) }
  let(:expected_organization_order) { [organization3, organization2, organization1].map(&:id) }

  let!(:organization_admin) { organization2.organization_admins.first }
  let!(:e_intervention_admin) { organization2.e_intervention_admins.first }

  let(:roles) do
    {
      'organization_admin' => organization_admin,
      'e_intervention_admin' => e_intervention_admin
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_organizations_path, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_organizations_path }

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
            'id' => organization1.id.to_s,
            'type' => 'organization',
            'attributes' => {
              'name' => organization1.name
            },
            'relationships' => {
              'e_intervention_admins' => { 'data' => [] },
              'organization_admins' => { 'data' => [] },
              'health_clinics' => { 'data' => [{ 'id' => health_clinic.id, 'type' => 'health_clinic' }] },
              'health_systems' => { 'data' => [{ 'id' => health_system.id, 'type' => 'health_system' }] }
            }
          },
          {
            'id' => organization2.id.to_s,
            'type' => 'organization',
            'attributes' => {
              'name' => organization2.name
            },
            'relationships' => {
              'e_intervention_admins' => { 'data' => [{ 'id' => e_intervention_admin.id, 'type' => 'user' }] },
              'organization_admins' => { 'data' => [{ 'id' => organization_admin.id, 'type' => 'user' }] },
              'health_clinics' => { 'data' => [] },
              'health_systems' => { 'data' => [] }
            }
          },
          {
            'id' => organization3.id.to_s,
            'type' => 'organization',
            'attributes' => {
              'name' => organization3.name
            },
            'relationships' => {
              'e_intervention_admins' => { 'data' => [] },
              'organization_admins' => { 'data' => [] },
              'health_clinics' => { 'data' => [] },
              'health_systems' => { 'data' => [] }
            }
          }
        )
      end

      it 'returns data in correct order' do
        result = json_response['data'].map { |org_json| org_json['id'] }
        expect(result).to eq(expected_organization_order)
      end

      it 'returns proper included data' do
        expect(json_response['included'][0]).to include(
          {
            'id' => health_clinic.id,
            'type' => 'health_clinic',
            'attributes' => {
              'health_system_id' => health_system.id,
              'name' => health_clinic.name,
              'deleted' => false
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] }, 'health_clinic_invitations' => { 'data' => [] } }
          }
        )
        expect(json_response['included'][1]).to include(
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
          let(:user) { roles[role] }

          before { request }

          it 'returns proper collection size' do
            expect(json_response['data'].size).to eq(1)
          end

          it 'returns proper collection data' do
            expect(json_response['data']).to include(
              {
                'id' => organization2.id.to_s,
                'type' => 'organization',
                'attributes' => {
                  'name' => organization2.name
                },
                'relationships' => {
                  'e_intervention_admins' => { 'data' => [{ 'id' => e_intervention_admin.id, 'type' => 'user' }] },
                  'organization_admins' => { 'data' => [{ 'id' => organization_admin.id, 'type' => 'user' }] },
                  'health_clinics' => { 'data' => [] },
                  'health_systems' => { 'data' => [] }
                }
              }
            )
          end

          it 'returns proper included data' do
            expect(json_response['included']).to eql([])
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

  context 'when user is health clinic admin' do
    let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, health_system: health_system) }
    let!(:other_organization) { create(:organization, name: 'Other Organization', created_at: DateTime.now - 10.days) }
    let!(:other_health_system) { create(:health_system, name: 'Other Health System', organization: other_organization) }
    let!(:other_health_clinic) { create(:health_clinic, name: 'Health Clinic 1234', health_system: other_health_system) }
    let(:user) { health_clinic.user_health_clinics.first.user }

    before do
      other_health_clinic.user_health_clinics << UserHealthClinic.create!(user: user, health_clinic: other_health_clinic)
      HealthClinicInvitation.create!(user: user, health_clinic: other_health_clinic)
      request
    end

    it 'returns correct collection data size' do
      expect(json_response['data'].size).to eq(1)
    end

    it 'returns correct data' do
      expect(json_response['data']).to include(
        {
          'id' => organization1.id.to_s,
          'type' => 'simple_organization',
          'attributes' => {
            'name' => organization1.name
          }
        }
      ).and not_include({
                          'id' => other_organization.id.to_s,
                          'type' => 'simple_organization',
                          'attributes' => {
                            'name' => other_organization.name
                          }
                        })
    end
  end
end
