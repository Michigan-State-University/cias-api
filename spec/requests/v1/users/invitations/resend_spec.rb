# frozen_string_literal: true

RSpec.describe 'POST /v1/users/invitations/resend', type: :request do
  let_it_be(:admin) { create(:user, :confirmed, :admin) }
  let(:invitation_token) { 'EYKPJ9P5y2Kc3Jp7juvq' }
  let!(:user_with_pending_invitation) do
    create(
      :user,
      :researcher,
      email: 'test@example.com',
      invitation_token: Devise.token_generator.digest(self, :invitation_token, invitation_token),
      invitation_accepted_at: nil
    )
  end
  let(:params) do
    {
      id: user_with_pending_invitation.id
    }
  end

  let(:request) { post v1_resend_invitation_path, headers: admin.create_new_auth_token, params: params }

  before { request }

  context 'correct invitation re-send' do
    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct user data' do
      expect(json_response['data']['attributes']['email']).to eq(user_with_pending_invitation.email)
      expect(User.find(json_response['data']['id']).roles).to match_array(%w[researcher])
    end
  end

  context 'non-admin user tries resending invitation' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:request) { post v1_resend_invitation_path(id: user_with_pending_invitation.id), headers: user.create_new_auth_token }

    it 'returns correct HTTP status code (Forbidden)' do
      expect(response).to have_http_status(:forbidden)
    end
  end
end
