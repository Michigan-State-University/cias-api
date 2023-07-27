# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/interventions/:intervention_id/collaborators', type: :request do
  let(:user) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, :with_collaborators, user: user) }
  let(:editor) { intervention.collaborators.first.user }
  let(:current_user) { user }

  let(:request) { get v1_intervention_collaborators_path(intervention.id), headers: current_user.create_new_auth_token }

  before { request }

  context 'when the user is an owner' do
    it 'return correct data' do
      expect(json_response['data'].first.deep_transform_keys(&:to_sym)).to include({
                                                                                     id: intervention.collaborators.first.id,
                                                                                     type: 'collaborator',
                                                                                     attributes: include({
                                                                                                           view: true,
                                                                                                           edit: true,
                                                                                                           data_access: false,
                                                                                                           user: include({
                                                                                                                           id: editor.id,
                                                                                                                           email: editor.email,
                                                                                                                           full_name: editor.full_name
                                                                                                                         })
                                                                                                         })
                                                                                   })
    end

    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when it is other researcher without access to specific intervention' do
    let(:current_user) { create(:user, :researcher, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when current user cannot see interventions' do
    let(:current_user) { create(:user, :participant, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when user has super admin permissions' do
    let(:current_user) { create(:user, :admin, :confirmed) }

    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'return not empty collection' do
      expect(json_response['data'].any?).to be true
    end
  end
end
