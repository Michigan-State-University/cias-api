# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/users/invitations', type: :request do
  let(:request) { get v1_invitations_path, headers: headers }

  let!(:user_with_pending_invitation)  { create(:user, :researcher, email: 'test@example.com', invitation_token: '00153b6800b53e4ce6f1d369505e0958fff90e198363e26c9093e17774fc6ed8', invitation_accepted_at: nil) }
  let!(:user_without_invitation)       { create(:user, :researcher, email: 'other@example.com', invitation_token: nil, invitation_accepted_at: nil) }
  let!(:user_with_accepted_invitation) { create(:user, :researcher, email: 'another@example.com', invitation_token: 'dsadasdas800b53e4ce6f1d369505e0958fff90e198363e26c9093e17774fc6ed8', invitation_accepted_at: Time.current) }

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    before do
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct pending invitations size' do
      expect(json_response['invitations'].size).to eq 0
    end
  end

  context 'when authenticated as researcher user' do
    let(:researcher_user) { create(:user, :researcher) }
    let(:headers)         { researcher_user.create_new_auth_token }

    before do
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct pending invitations size' do
      expect(json_response['invitations'].size).to eq 0
    end
  end

  context 'when authenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    before do
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct pending invitations size' do
      expect(json_response['invitations'].size).to eq 1
    end

    it 'returns correct email' do
      expect(json_response['invitations'][0]['email']).to eq 'test@example.com'
    end
  end
end
