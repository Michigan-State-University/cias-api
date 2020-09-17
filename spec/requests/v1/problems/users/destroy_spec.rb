# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/problems/:problem_id/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:participant) { create(:user, :participant) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:interventions) { create_list(:intervention, 2, problem_id: problem.id) }
  let(:user_interventions) do
    interventions.each do |intervention|
      intervention.user_interventions.create(user_id: participant.id)
    end
    problem.user_interventions
  end
  let(:request) { delete v1_problem_user_path(problem_id: problem.id, id: participant.id), headers: user.create_new_auth_token }

  context 'destroy user_intervention' do
    it 'expect interventions not to have any user_interventions ' do
      user_interventions
      request

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(user_interventions.size).to eq 0
    end
  end
end
