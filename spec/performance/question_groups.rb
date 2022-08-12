# frozen_string_literal: true

RSpec.describe 'Performance', type: :request do
  context 'Report templates' do
    let!(:user) { create(:user, :confirmed, :admin) }
    let!(:headers) { user.create_new_auth_token }
    let!(:session) { create(:session) }
    let!(:question_groups) { create_list(:question_group, 20, session: session) }
    let!(:question_group) { create(:question_group, session: session) }

    it 'performs index in correct time' do
      expect { get v1_session_question_groups_path(session_id: session.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end

    it 'performs show in correct time' do
      expect { get v1_session_question_group_path(session_id: session.id, id: question_group.id), headers: headers }
        .to perform_under(0.2).sample(10)
    end
  end
end

