# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/health_systems/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) do
    create(:health_system, :with_health_system_admin, name: 'Michigan Public Health System', organization: organization)
  end
  let!(:health_system_admin_id) { health_system.health_system_admins.first.id }

  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_health_system_path(health_system.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_health_system_path(health_system.id) }

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
        expect(response).to have_http_status(:no_content)
      end

      it 'health system is deleted' do
        expect(HealthSystem.find_by(id: health_system.id)).to eq(nil)
      end

      it 'health system admin doesn\'t belong to health system' do
        expect(User.find(health_system_admin_id).organizable).to eq(nil)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when health system id is invalid' do
        before do
          delete v1_health_system_path('wrong_id'), headers: headers
        end

        it 'error message is expected' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when user has multiple roles' do
      let(:user) { create(:user, :confirmed, roles: %w[participant admin guest]) }

      it_behaves_like 'permitted user'
    end

    context 'when user is e-intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    %i[health_system_admin organization_admin team_admin researcher participant guest
       health_clinic_admin].each do |role|
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
