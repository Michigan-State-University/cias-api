# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/invitations', type: :request do
  let(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let(:problem) { create(:problem, user_id: user.id) }
  let(:intervention) { create(:intervention, problem_id: problem.id) }
  let(:new_intervention_invitation) { 'a@a.com' }
  let(:params) do
    {
      intervention_invitation: {
        emails: [new_intervention_invitation]
      }
    }
  end
  let(:request) { post v1_intervention_invitations_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  context 'create intervention invitation' do
    it 'with success' do
      request

      expect(response).to have_http_status(:created)
      expect(json_response['intervention_invitations'].first).to include(
        'intervention_id' => intervention.id,
        'email' => new_intervention_invitation
      )
      expect(InterventionInvitation.find_by(email: new_intervention_invitation)).not_to be_nil
    end
  end
end
