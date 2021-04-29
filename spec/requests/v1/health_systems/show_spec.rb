# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_systems/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:organization_1) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Oregano Public Health') }
  let!(:health_system_1) { create(:health_system, :with_health_system_admin, organization: organization_1, name: 'Test') }

  let(:roles_organization) do
    {
      'organization_admin' => organization.organization_admins.first,
      'e_intervention_admin' => organization.e_intervention_admins.first
    }
  end
  let(:roles_organization_1) do
    {
      'organization_admin' => organization_1.organization_admins.first,
      'e_intervention_admin' => organization_1.e_intervention_admins.first
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
              'name' => health_system.name
            }
          }
        )
      end

      it 'returns proper collection size' do
        expect(json_response.size).to eq(1)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when admin has multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[admin participant]) }

      it_behaves_like 'permitted user'
    end

    context 'when user is' do
      %w[organization_admin e_intervention_admin].each do |role|
        context role.to_s do
          context 'refers to their health_system' do
            let(:user) { roles_organization[role] }

            it_behaves_like 'permitted user'
          end

          context 'doesn\'t refer to other health_system' do
            let(:user) { roles_organization_1[role] }

            before { request }

            it 'returns proper error message' do
              expect(json_response['message']).to include('Couldn\'t find HealthSystem with')
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
