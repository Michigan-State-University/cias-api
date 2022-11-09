# frozen_string_literal: true

RSpec.describe V1::Organizations::Destroy, type: :request do
  subject { described_class.call(organization) }

  let!(:organization) { create(:organization, name: 'Original organization name') }
  let!(:health_system) { create(:health_system, organization_id: organization.id, name: 'Original system name') }
  let!(:health_clinic) { create(:health_clinic, health_system_id: health_system.id, name: 'Original clinic name') }
  let!(:admin) { create(:user, :confirmed, :admin) }

  let!(:invite_clinic_admin_request) do
    post v1_health_clinic_invitations_invite_health_clinic_admin_path(health_clinic_id: health_clinic.id),
         params: clinic_admin_params, headers: admin.create_new_auth_token
  end
  let!(:invite_system_admin_request) do
    post v1_health_system_invitations_invite_health_system_admin_path(health_system_id: health_system.id),
         params: system_admin_params, headers: admin.create_new_auth_token
  end
  let!(:invite_organization_admin_request) do
    post v1_organization_invitations_invite_organization_admin_path(organization_id: organization.id),
         params: organization_admin_params, headers: admin.create_new_auth_token
  end
  let!(:invite_intervention_admin_request) do
    post v1_organization_invitations_invite_intervention_admin_path(organization_id: organization.id),
         params: intervention_admin_params, headers: admin.create_new_auth_token
  end

  let!(:clinic_admin_params) { { email: 'health@clinic.ad', health_clinic_id: health_clinic.id }}
  let!(:system_admin_params) { { email: 'health@system.ad', health_system_id: health_system.id }}
  let!(:organization_admin_params) { { email: 'organization@admin.jd', organization_id: organization.id }}
  let!(:intervention_admin_params) { { email: 'intervention@admin.dj', organization_id: organization.id }}

  context 'valid deletion' do
    before do
      invite_clinic_admin_request
      invite_system_admin_request
      invite_organization_admin_request
      invite_intervention_admin_request
    end

    it 'delete all invited user who did not accept their invitations' do
      expect { subject }.to change(Organization, :count).by(-1)
    end

    it 'deletes invited user before organization is deleted' do
      expect { subject }.to change(User, :count).by(-4)
    end

    context 'confirmed invite' do
      let!(:clinic_admin_params) { { email: 'accepted@clinic.ad', health_clinic_id: health_clinic.id }}

      before do
        invite_clinic_admin_request
        User.find_by(email: 'accepted@clinic.ad').confirm
      end
      it 'do not delete user which accepted an invitation' do
        subject
        expect(User.all).to include(User.find_by(email: 'accepted@clinic.ad'))
      end
    end
  end
end
