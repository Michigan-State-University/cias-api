# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:session_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:intervention) { create(:intervention, user_id: user.id) }
  let(:session) { create(:session, intervention_id: intervention.id) }
  let(:session_invitation) { create_list(:session_invitation, 2, session_id: session.id) }

  let(:request) { get v1_session_invitations_path(session_id: session.id), headers: user.create_new_auth_token }

  context 'will retrive all associated session_inviataions' do
    it 'with success' do
      session_invitation
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['session_invitations'].size).to eq session_invitation.size
    end
  end
end
