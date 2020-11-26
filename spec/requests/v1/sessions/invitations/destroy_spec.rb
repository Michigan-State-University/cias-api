# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sessions/:session_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:session) { create(:session, problem_id: problem.id) }
  let(:session_invitation) { create(:session_invitation, session_id: session.id) }
  let(:request) { delete v1_session_invitation_path(session_id: session.id, id: session_invitation.id), headers: user.create_new_auth_token }

  context 'destroy session_invitation' do
    it 'with success' do
      session_invitation
      request

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(session.user_sessions.size).to eq 0
    end
  end
end
