# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/users/invitations', type: :request do
  let(:request) { delete v1_invitation_path(user_with_pending_invitation), headers: headers }

  let!(:user_with_pending_invitation) { create(:user, email: 'test@example.com', invitation_token: 'EXAMPLE_TOKEN', invitation_accepted_at: nil) }

  context 'when autenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns not_found status' do
      request

      expect(response).to have_http_status(:not_found)
      expect(user_with_pending_invitation.reload.invitation_token).to eq 'EXAMPLE_TOKEN'
    end
  end

  context 'when auhtenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    it 'returns no_content status' do
      request

      expect(response).to have_http_status(:no_content)
      expect(User.find_by(email: 'test@example.com')).to eq nil
    end
  end
end
