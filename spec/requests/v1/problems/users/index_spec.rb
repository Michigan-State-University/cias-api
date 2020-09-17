# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/problems/:problem_id/users', type: :request do
  let!(:user) { create(:user, :confirmed, :admin) }
  let!(:users) { create_list(:user, 4, :confirmed) }
  let!(:problem) { create(:problem, user_id: user.id) }
  let!(:interventions) { create_list(:intervention, 2, problem_id: problem.id) }
  let!(:user_interventions) do
    users.each do |user|
      interventions.each do |intervention|
        intervention.user_interventions.create(user_id: user.id)
      end
    end
  end
  let(:request) { get v1_problem_users_path(problem_id: problem.id), headers: user.create_new_auth_token }

  context 'will retrive all users associated to interventions' do
    it 'user previously exist in system' do
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['user_interventions'].size).to eq 4
    end
  end
end
