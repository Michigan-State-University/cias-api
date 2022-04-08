# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :admin) }
  let!(:users) { create_list(:user, 4, :confirmed) }
  let!(:intervention) { create(:intervention, user_id: user.id, invitations: users_with_access) }
  let!(:users_with_access) { create_list(:intervention_invitation, 3) }
  let(:request) do
    get v1_intervention_invitations_path(intervention_id: intervention.id), headers: user.create_new_auth_token
  end

  context 'will retrieve all users that were added to the access list' do
    before do
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct invitations size' do
      expect(json_response['data'].size).to eq 3
    end
  end
end
