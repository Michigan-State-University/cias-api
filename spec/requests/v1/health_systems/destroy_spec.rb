# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/health_systems/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
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

  let!(:organization) { create(:organization, :with_e_intervention_admin) }
  let!(:health_system) do
    create(:health_system, :with_health_system_admin, name: 'Michigan Public Health System', organization: organization)
  end
  let!(:health_system_admin_id) { health_system.health_system_admins.first.id }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, health_system: health_system) }
  let!(:health_clinic_admin_id) { health_clinic.health_clinic_admins.first.id }
  let!(:chart_statistic) { create(:chart_statistic, health_system: health_system) }

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
        expect(HealthSystem.find_by(id: health_system.id)).to be_nil
      end

      it 'health system admin doesn\'t belong to health system' do
        expect(User.find(health_system_admin_id).organizable).to be_nil
      end

      it 'health_system admin active status is false' do
        expect(User.find(health_system_admin_id).active?).to be(false)
      end

      it 'health_clinic is deleted' do
        expect(HealthClinic.find_by(id: health_clinic.id)).to be_nil
      end

      it 'health_clinic admins doesn\'t belongs to health_clinic' do
        expect(User.find(health_clinic_admin_id).organizable_id).to be_nil
        expect(User.find(health_clinic_admin_id).user_health_clinics).to eq([])
      end

      it 'health_clinic admin active status is false' do
        expect(User.find(health_clinic_admin_id).active?).to be(false)
      end

      it 'does not change chart statistic count' do
        expect { request }.to avoid_changing(ChartStatistic, :count)
      end

      context 'when health system id is invalid' do
        before do
          delete v1_health_system_path('wrong_id'), headers: headers
        end

        it 'error message is expected' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
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

    %i[health_system_admin organization_admin team_admin researcher participant guest
       health_clinic_admin third_party].each do |role|
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
