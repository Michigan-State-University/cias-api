# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/health_system/confirm', type: :request do
  let(:request) do
    get v1_health_system_invitations_confirm_path(invitation_token: invitation_token), params: params,
                                                                                       headers: headers
  end
  let!(:health_system) { create(:health_system) }
  let!(:health_system_admin) { create(:user, :confirmed, :health_system_admin) }

  let(:params) { { invitation_token: invitation_token } }
  let(:success_message) do
    { success: Base64.encode64(I18n.t('organizables.invitations.accepted', organizable_type: 'Health System', organizable_name: health_system.name)) }.to_query
  end
  let(:success_path) do
    "#{ENV['WEB_URL']}?#{success_message}"
  end
  let(:error_message) do
    { error: Base64.encode64(I18n.t('organizables.invitations.not_found', organizable_type: 'Health System')) }.to_query
  end
  let(:error_path) do
    "#{ENV['WEB_URL']}?#{error_message}"
  end
  let(:headers) { health_system_admin.create_new_auth_token }

  context 'when user is health system admin' do
    context 'when invitation_token is valid' do
      let!(:health_system_invitation) { create(:health_system_invitation, user_id: health_system_admin.id, health_system_id: health_system.id) }
      let(:invitation_token) { health_system_invitation.invitation_token }

      it 'confirms health system invitation and assign user to the health system' do
        expect { request }.to change { health_system_admin.reload.organizable_id }.from(nil).to(health_system.id).and \
          change { health_system_invitation.reload.accepted_at }.and \
            change(health_system_invitation, :invitation_token).to(nil)
      end

      it 'redirects to the web app with success message' do
        expect(request).to redirect_to(success_path)
      end
    end
  end

  context 'when invitation_token is invalid' do
    context 'when invitation token does not exist' do
      let(:invitation_token) { 'invalid-token' }

      it 'redirect user to the web app with error message' do
        expect(request).to redirect_to(error_path)
      end
    end

    context 'when invitation token has been already accepted' do
      let!(:health_system_invitation) do
        create(:health_system_invitation, :accepted, user_id: health_system_admin.id, health_system_id: health_system.id)
      end
      let(:invitation_token) { health_system_invitation.invitation_token }

      it 'redirect user to the web app with error message' do
        expect(request).to redirect_to(error_path)
      end
    end
  end
end
