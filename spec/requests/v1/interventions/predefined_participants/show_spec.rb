# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/predefined_participants/:id', type: :request do
  let!(:intervention) { create(:intervention, :with_predefined_participants, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:user) { intervention.predefined_users.first }
  let(:user_id) { user.id }
  let(:current_user) { researcher }
  let(:request) do
    get v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: user_id), headers: current_user.create_new_auth_token
  end

  it 'return correct status' do
    request
    expect(response).to have_http_status(:ok)
  end

  it 'return correct body' do
    request
    expect(json_response['data']['id']).to eql(user.id)
  end

  context 'when id is wrong' do
    let(:user_id) { 'wrongId' }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'other researcher' do
    let(:current_user) { create(:user, :researcher, :confirmed) }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'other role' do
    let(:current_user) { create(:user, :participant, :confirmed) }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end
