# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/health_systems', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Oregano Public Health') }
  let(:e_intervention_admin) { organization.e_intervention_admins.first }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }
  let(:user) { admin }

  let(:roles) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles,
      'e_intervention_admin' => e_intervention_admin
    }
  end

  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      health_system: {
        name: 'New Health System',
        organization_id: organization.id
      }
    }
  end
  let(:request) { post v1_health_systems_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_health_systems_path }

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
        expect(response).to have_http_status(:created)
      end

      it 'returns proper data' do
        expect(json_response['data']).to include(
          {
            'type' => 'health_system',
            'attributes' => {
              'name' => 'New Health System',
              'organization_id' => organization.id,
              'deleted' => false
            },
            'relationships' => {
              'health_system_admins' => { 'data' => [] },
              'health_clinics' => { 'data' => [] }
            }
          }
        )
      end

      context 'when params are invalid' do
        let(:params) do
          {
            health_system: {
              name: ''
            }
          }
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq "Validation failed: Organization must exist, Name can't be blank"
        end
      end
    end

    %w[admin admin_with_multiple_roles e_intervention_admin].each do |role|
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
