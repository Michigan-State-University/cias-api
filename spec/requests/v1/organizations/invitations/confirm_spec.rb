# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/organization/confirm', type: :request do
  let(:request) do
    get v1_organization_invitations_confirm_path(invitation_token: invitation_token), params: params,
                                                                                      headers: headers
  end
  let!(:organization) { create(:organization) }
  let!(:intervention_admin) { create(:user, :confirmed, :e_intervention_admin, active: false) }
  let!(:organization_admin) { create(:user, :confirmed, :organization_admin, active: false) }

  let(:params) { { invitation_token: invitation_token } }
  let(:success_message) do
    { success: Base64.encode64(I18n.t('organizables.invitations.accepted', organizable_type: 'Organization',
                                                                           organizable_name: organization.name)) }.to_query
  end
  let(:success_path) do
    "#{ENV['WEB_URL']}?#{success_message}"
  end
  let(:error_message) do
    { error: Base64.encode64(I18n.t('organizables.invitations.not_found', organizable_type: 'Organization')) }.to_query
  end
  let(:error_path) do
    "#{ENV['WEB_URL']}?#{error_message}"
  end
  let(:headers) { intervention_admin.create_new_auth_token }

  context 'when user is intervention admin' do
    context 'when invitation_token is valid' do
      let!(:organization_invitation) do
        create(:organization_invitation, user_id: intervention_admin.id, organization_id: organization.id)
      end
      let(:invitation_token) { organization_invitation.invitation_token }

      it 'confirms organization invitation and assign user to the organization' do
        expect { request }.to change { organization_invitation.reload.accepted_at }.and \
          change(organization_invitation, :invitation_token).to(nil)
      end

      it 'redirects to the web app with success message' do
        expect(request).to redirect_to(success_path)
      end
    end
  end

  context 'when user is organization admin' do
    context 'when invitation_token is valid' do
      let(:headers) { organization_admin.create_new_auth_token }
      let!(:organization_invitation) do
        create(:organization_invitation, user_id: organization_admin.id, organization_id: organization.id)
      end
      let(:invitation_token) { organization_invitation.invitation_token }

      it 'confirms organization invitation and assign user to the organization' do
        expect { request }.to change { organization_invitation.reload.accepted_at }.and \
          change(organization_invitation, :invitation_token).to(nil)
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
      let!(:organization_invitation) do
        create(:organization_invitation, :accepted, user_id: intervention_admin.id, organization_id: organization.id)
      end
      let(:invitation_token) { organization_invitation.invitation_token }

      it 'redirect user to the web app with error message' do
        expect(request).to redirect_to(error_path)
      end
    end
  end
end
