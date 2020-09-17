# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:intervention) { create(:intervention, problem_id: problem.id) }
  let(:intervention_invitation) { create_list(:intervention_invitation, 2, intervention_id: intervention.id) }

  let(:request) { get v1_intervention_invitations_path(intervention_id: intervention.id), headers: user.create_new_auth_token }

  context 'will retrive all associated intervention_inviataions' do
    it 'with success' do
      intervention_invitation
      request

      expect(response).to have_http_status(:ok)
      expect(json_response['intervention_invitations'].size).to eq intervention_invitation.size
    end
  end
end
