# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/organizations/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, :with_organization_admin, name: 'Michigan Public Health') }
  let!(:intervention_admin_id) { organization.e_intervention_admins.first.id }
  let!(:organization_admin_id) { organization.organization_admins.first.id }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_system_admin_id) { health_system.health_system_admins.first.id }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, health_system: health_system) }
  let!(:health_clinic_admin_id) { health_clinic.health_clinic_admins.first.id }
  let!(:intervention) { create(:intervention, organization_id: organization.id) }

  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_organization_path(organization.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_organization_path(organization.id) }

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

      it 'organization is deleted' do
        expect(Organization.find_by(id: organization.id)).to be_nil
      end

      it 'intervention admins doesn\'t belongs to organization' do
        expect(User.find(intervention_admin_id).organizable_id).to be_nil
      end

      it 'intervention admin active status is false' do
        expect(User.find(intervention_admin_id).active?).to be(true)
      end

      it 'organization admins doesn\'t belongs to organization' do
        expect(User.find(organization_admin_id).organizable_id).to be_nil
      end

      it 'organization admin active status is true' do
        expect(User.find(organization_admin_id).active?).to be(false)
      end

      it 'health_system is deleted' do
        expect(HealthSystem.find_by(id: health_system.id)).to be_nil
      end

      it 'health_system admins doesn\'t belongs to health_system' do
        expect(User.find(health_system_admin_id).organizable_id).to be_nil
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

      it 'intervention of deleted organization changed field from_deleted_organization from false to true' do
        expect(intervention.reload.from_deleted_organization).to be(true)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when organization id is invalid' do
        before do
          delete v1_organization_path('wrong_id'), headers: headers
        end

        it 'error message is expected' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'when one of the multiple roles is admin' do
      let(:user) { create(:user, :confirmed, roles: %w[participant admin guest]) }

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

    %i[organization_admin team_admin researcher participant guest].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }
        let(:headers) { user.create_new_auth_token }

        it_behaves_like 'unpermitted user'
      end
    end

    context 'when user is e-intervention admin' do
      let(:user) { organization.e_intervention_admins.first }

      it_behaves_like 'unpermitted user'
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
