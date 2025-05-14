# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/teams/invitations/confirm', type: :request do
  let(:request) do
    get v1_team_invitations_confirm_path(invitation_token: invitation_token), params: params,
                                                                              headers: headers
  end
  let!(:researcher) { create(:user, :confirmed, roles: %w[researcher guest]) }
  let!(:team) { create(:team) }
  let(:params) { { invitation_token: invitation_token } }
  let(:success_message) do
    { success: Base64.encode64(I18n.t('teams.invitations.accepted', team_name: team.name)) }.to_query
  end
  let(:success_path) do
    "#{ENV.fetch('WEB_URL', nil)}?#{success_message}"
  end
  let(:error_message) do
    { error: Base64.encode64(I18n.t('teams.invitations.not_found')) }.to_query
  end
  let(:error_path) do
    "#{ENV.fetch('WEB_URL', nil)}?#{error_message}"
  end

  context 'when invitation_token is valid' do
    let!(:team_invitation) { create(:team_invitation, user_id: researcher.id, team_id: team.id) }
    let(:invitation_token) { team_invitation.invitation_token }

    it 'confirms team invitation and assign user to the team' do
      expect { request }.to change { researcher.reload.team_id }.from(nil).to(team.id).and \
        change { team_invitation.reload.accepted_at }.and \
          change(team_invitation, :invitation_token).to(nil)
    end

    it 'redirects to the web app with success message' do
      expect(request).to redirect_to(success_path)
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
      let!(:team_invitation) do
        create(:team_invitation, :accepted, user_id: researcher.id, team_id: team.id)
      end
      let(:invitation_token) { team_invitation.invitation_token }

      it 'redirect user to the web app with error message' do
        expect(request).to redirect_to(error_path)
      end
    end
  end
end
