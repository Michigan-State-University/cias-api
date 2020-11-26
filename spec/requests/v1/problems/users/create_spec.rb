# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/problems/:problem_id/users', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:user_admin_1) { create(:user, :confirmed, :admin, first_name: 'John', last_name: 'Twain', email: 'john.twain@test.com', created_at: 5.days.ago) }
  let(:user_admin_2) { create(:user, :confirmed, :participant, created_at: 4.days.ago) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:sessions) { create_list(:session, 2, problem_id: problem.id) }
  let(:not_add_user_by_email) { 'a@a.com' }
  let(:params) do
    {
      user_session: {
        emails: [user_admin_1.email, not_add_user_by_email]
      }
    }
  end

  let(:request) { post v1_problem_users_path(problem_id: problem.id), params: params, headers: user.create_new_auth_token }

  context 'create users' do
    let(:params) do
      {
        user_session: {
          emails: [user_admin_1.email, user_admin_2.email]
        }
      }
    end

    it 'user to all sessions' do
      sessions
      request

      expect(response).to have_http_status(:created)
      expect(json_response['user_sessions'].size).to eq 2
      expect(json_response['user_sessions'].pluck('user_id').uniq).to match_array([user_admin_1.id, user_admin_2.id])
      expect(User.find_by(email: not_add_user_by_email)).to be nil
    end

    it 'many users to many sessions' do
      sessions
      request

      expect(response).to have_http_status(:created)
      expect(json_response['user_sessions'].size).to eq 2
      expect(json_response['user_sessions'].pluck('user_id').uniq).to match_array([user_admin_1.id, user_admin_2.id])
    end
  end
end
