# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:session_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:intervention) { create(:intervention, user_id: user.id) }
  let(:session) { create(:session, intervention_id: intervention.id, invitations: session_invitations) }
  let(:session_invitations) { create_list(:session_invitation, 3) }

  let(:request) { get v1_session_invitations_path(session_id: session.id), headers: user.create_new_auth_token }

  context 'will retrieve all associated session invitations' do
    before do
      request
    end

    it 'returns correct http code' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct invitations size' do
      expect(json_response['data'].size).to eq session_invitations.size
    end
  end
end
