# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/interventions/:intervention_id/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:participant) { create(:user, :participant) }
  let(:intervention) { create(:intervention, user_id: user.id) }
  let(:sessions) { create_list(:session, 2, intervention_id: intervention.id) }
  let(:user_sessions) do
    sessions.each do |session|
      session.user_sessions.create(user_id: participant.id)
    end
    intervention.user_sessions
  end
  let(:request) { delete v1_intervention_user_path(intervention_id: intervention.id, id: participant.id), headers: user.create_new_auth_token }

  context 'destroy user_session' do
    it 'expect sessions not to have any user_sessions ' do
      user_sessions
      request

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(user_sessions.size).to eq 0
    end
  end
end
