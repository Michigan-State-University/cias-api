# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Intervention' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:params) { { start_index: 0, end_index: 50 } }
    let!(:interventions) { create_list(:intervention, 50, :published, user_id: user.id) }

    let!(:sessions) { create_list(:session, 50) }
    let!(:intervention) { create(:intervention, :published, user_id: user.id, sessions: sessions) }

    it 'performs index in correct time' do
      # TO FIX
      expect { get v1_interventions_path, params: params, headers: user.create_new_auth_token }
        .to perform_under(0.5).sample(10)
    end

    it 'performs show in correct time' do
      expect { get v1_intervention_path(intervention.id), headers: user.create_new_auth_token }
        .to perform_under(0.25).sample(10)
    end
  end
end
