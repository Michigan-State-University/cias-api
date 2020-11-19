# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/interventions/:intervention_id/users/:id', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let!(:participant) { create(:user, :participant) }
  let!(:intervention) { create(:intervention, user_id: user.id, invitations: [user_with_access]) }
  let!(:user_with_access) { create(:intervention_invitation) }
  let(:request) { delete v1_intervention_invitation_path(intervention_id: intervention.id, id: user_with_access.id), headers: user.create_new_auth_token }

  context 'remove user with access' do
    before do
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:no_content)
    end

    it 'returns empty body' do
      expect(response.body).to be_empty
    end

    it 'sets correct intervention invitation size' do
      expect(intervention.reload.invitations.size).to eq 0
    end
  end
end
