# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:session_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:session) { create(:session, problem_id: problem.id) }
  let(:new_session_invitation) { 'a@a.com' }
  let(:params) do
    {
      session_invitation: {
        emails: [new_session_invitation]
      }
    }
  end
  let(:request) { post v1_session_invitations_path(session_id: session.id), params: params, headers: user.create_new_auth_token }

  context 'create session invitation' do
    it 'with success' do
      request

      expect(response).to have_http_status(:created)
      expect(json_response['session_invitations'].first).to include(
        'session_id' => session.id,
        'email' => new_session_invitation
      )
      expect(SessionInvitation.find_by(email: new_session_invitation)).not_to be_nil
    end
  end
end
