# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_systems', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_health_system, :with_organization_admin, :with_e_intervention_admin) }
  let!(:health_system) { organization.health_systems.first }
  let!(:health_system_2) { create(:health_system, :with_health_system_admin, name: 'Health System 2') }
  let!(:organization_2) { health_system_2.organization }
  let!(:health_clinic) { create(:health_clinic) }
  let!(:health_system_3) { health_clinic.health_system }

  let!(:health_system_admin) { health_system_2.health_system_admins.first }

  let(:roles) do
    {
      'organization_admin' => organization.organization_admins.first,
      'e_intervention_admin' => organization.e_intervention_admins.first
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
              'organization_id' => health_system.organization_id
            },
            'relationships' =>
                {
                  'health_system_admins' => { 'data' => [] },
                  'health_clinics' => { 'data' => [] }
                }
          },
          {
            'id' => health_system_2.id.to_s,
            'type' => 'health_system',
            'attributes' => {
              'name' => health_system_2.name,
              'organization_id' => health_system_2.organization_id
            },
            'relationships' => {
              'health_system_admins' => { 'data' => [{ 'id' => health_system_admin.id, 'type' => 'user' }] },
              'health_clinics' => { 'data' => [] }
            }
          },
          {
            'id' => health_system_3.id,
            'type' => 'health_system',
            'attributes' => {
              'name' => health_system_3.name,
              'organization_id' => health_system_3.organization_id
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
              'health_system_id' => health_system_3.id,
              'name' => health_clinic.name
            },
            'relationships' => { 'health_clinic_admins' => { 'data' => [] } }
          }
        )
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when admin has multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[participant admin guest]) }

      it_behaves_like 'permitted user'
    end

    context 'when user is' do
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
                'id' => health_system.id.to_s,
                'type' => 'health_system',
                'attributes' => {
                  'name' => health_system.name,
                  'organization_id' => organization.id
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
    end
  end

  context 'when user is health system admin' do
    let!(:user) { health_system_admin }

    before { request }

    it 'returns proper collection size' do
      expect(json_response['data'].size).to eq(1)
    end

    it 'returns proper collection data' do
      expect(json_response['data']).to include(
        {
          'id' => health_system_2.id.to_s,
          'type' => 'health_system',
          'attributes' => {
            'name' => health_system_2.name,
            'organization_id' => health_system_2.organization.id
          },
          'relationships' => {
            'health_system_admins' => { 'data' => [{ 'id' => health_system_admin.id, 'type' => 'user' }] },
            'health_clinics' => { 'data' => [] }
          }
        }
      )
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
