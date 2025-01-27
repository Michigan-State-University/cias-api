# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/users/invitations', type: :request do
  let(:request)          { get edit_v1_invitations_path, params: params }
  let(:invitation_token) { 'EYKPJ9P5y2Kc3Jp7juvq' }

  let!(:user_without_invitation_token) { create(:user, :researcher, invitation_token: nil) }
  let!(:user_with_pending_invitation)  do
    create(
      :user,
      :researcher,
      email: 'test@example.com',
      invitation_token: Devise.token_generator.digest(self, :invitation_token, invitation_token),
      invitation_accepted_at: nil
    )
  end

  context 'when not authenticated' do
    context 'when invitation_token provided in params' do
      let(:params) { { invitation_token: invitation_token } }

      it 'redirects to web app register page' do
        request

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to("#{ENV.fetch('WEB_URL', nil)}/register?invitation_token=#{invitation_token}&email=#{user_with_pending_invitation.email}&role=researcher") # rubocop:disable Layout/LineLength
      end
    end

    context 'when invitation_token not provided in params' do
      let(:params) { { invitation_token: nil } }

      it 'redirects to web app register page' do
        request

        expect(response).to have_http_status(:found)
      end
    end
  end
end
