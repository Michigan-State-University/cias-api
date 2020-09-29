# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/interventions/:intervention_id/question_groups', type: :request do
  let(:request) { get v1_intervention_question_groups_path(intervention_id: intervention.id), headers: headers }

  let!(:intervention)    { create(:intervention, problem: create(:problem, :published)) }
  let!(:question_groups) { create_list(:question_group, 3, intervention: intervention) }

  context 'when authenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns list of serialized question_groups' do
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['question_groups'].size).to eq 4
    end
  end
end
