# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:intervention) { create(:intervention, problem_id: problem.id) }
  let(:intervention_invitation) { create(:intervention_invitation, intervention_id: intervention.id) }
  let(:request) { delete v1_intervention_invitation_path(intervention_id: intervention.id, id: intervention_invitation.id), headers: user.create_new_auth_token }

  context 'destroy intervention_invitation' do
    it 'with success' do
      intervention_invitation
      request

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(intervention.user_interventions.size).to eq 0
    end
  end
end
