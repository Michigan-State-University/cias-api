# frozen_string_literal: true

RSpec.describe V1::HealthClinics::Destroy, type: :request do
  subject { described_class.call(health_clinic) }

  let!(:health_clinic) { create(:health_clinic, name: 'Original clinic name') }
  let!(:admin) { create(:user, :confirmed, :admin) }

  let!(:invite_clinic_admin_request) do
    post v1_health_clinic_invitations_invite_health_clinic_admin_path(health_clinic_id: health_clinic.id),
         params: clinic_admin_params, headers: admin.create_new_auth_token
  end

  let!(:clinic_admin_params) { { email: 'health@clinic.ad', health_clinic_id: health_clinic.id } }

  context 'valid deletion' do
    before do
      invite_clinic_admin_request
    end

    it 'delete all invited user who did not accept their invitations' do
      expect { subject }.to change(HealthClinic, :count).by(-1)
    end

    it 'deletes invited user before organization is deleted' do
      expect { subject }.to change(User, :count).by(-1)
    end

    context 'confirmed invite' do
      let!(:clinic_admin_params) { { email: 'accepted@clinic.ad', health_clinic_id: health_clinic.id } }

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
