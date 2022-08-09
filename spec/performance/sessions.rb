# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Sessions' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }
    let!(:intervention) { create(:intervention, :published, user_id: user.id) }
    let!(:session) { create(:session, intervention_id: intervention.id) }

    it 'performs index in correct time' do
      expect { get v1_intervention_sessions_path(intervention.id), headers: headers }.to perform_under(0.25).sample(10)
    end

    it 'performs show in correct time' do
      expect { get v1_intervention_session_path(intervention_id: intervention.id, id: session.id), headers: headers }
        .to perform_under(0.25).sample(10)
    end
  end
end
