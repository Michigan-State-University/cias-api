# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/users/invitations', type: :request do
  let(:request)          { patch v1_invitations_path, params: params }
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
    context 'when valid params provided' do
      let(:params) do
        {
          invitation: {
            invitation_token: invitation_token,
            password: 'kytdhdn#@!',
            password_confirmation: 'kytdhdn#@!',
            first_name: 'Jhon',
            last_name: 'Doe'
          }
        }
      end

      it 'accepts new account' do
        request

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['email']).to eq 'test@example.com'
        expect(user_with_pending_invitation.reload.invitation_accepted_at).to be_present
        expect(user_with_pending_invitation.confirmed_at).to be_present
      end
    end

    context 'when invalid params provided' do
      let(:params) do
        {
          invitation: {
            invitation_token: 'INVALID_TOKEN',
            password: 'kytdhdn#@!',
            password_confirmation: 'kytdhdn#@!',
            first_name: 'Jhon',
            last_name: 'Doe'
          }
        }
      end

      it 'redirects to web app register page' do
        request

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq 'Invitation token is invalid'
      end
    end
  end
end
