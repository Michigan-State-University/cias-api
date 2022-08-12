# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Sessions' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }
    let!(:intervention) { create(:intervention, :published, user_id: user.id) }
    let!(:sessions) { create_list(:session, 50, intervention_id: intervention.id) }

    let!(:cat_mh_tests) { create_list(:cat_mh_test_type, 50) }
    let!(:session) { create(:cat_mh_session, variable: "htd", intervention_id: intervention.id, cat_mh_test_types: cat_mh_tests) }

    it 'performs index in correct time' do
      expect { get v1_intervention_sessions_path(intervention.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end

    it 'performs show in correct time' do
      expect { get v1_intervention_session_path(intervention_id: intervention.id, id: session.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end
  end
end
