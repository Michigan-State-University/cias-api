# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/collaborators', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, user: user) }
  let(:editor) { intervention.collaborators.first.user }
  let(:current_user) { user }
  let(:params) do
    {
      emails: ['new_researcher@example.com', researcher.email]
    }
  end

  let(:request) { post v1_intervention_collaborators_path(intervention.id), params: params, headers: current_user.create_new_auth_token }

  before { request }

  context 'when the user is an owner' do
    it 'return correct status' do
      expect(response).to have_http_status(:created)
    end

    it 'add new collaborators to the intervention' do
      expect(intervention.reload.collaborators.size).to be(2)
    end

    it 'new collaborators have correct emails' do
      user_ids = intervention.reload.collaborators.pluck(:user_id)
      expect(User.where(id: user_ids).map(&:email)).to match_array(params[:emails])
    end

    it 'have correct keys' do
      expect(json_response['data'].first['attributes'].keys).to match_array(%w[id view edit data_access user])
    end
  end

  context 'when collaborator wants to add another collaborator' do
    let(:intervention) { create(:intervention, :with_collaborators, user: user) }
    let(:current_user) { intervention.collaborators.first.user }

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when user without access' do
    let(:current_user) { create(:user, :participant, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end
  end
end
