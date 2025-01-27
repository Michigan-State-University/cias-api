# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET v1/interventions/:id/generated_conversations_transcript', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, :with_collaborators, user: researcher, conversations_transcript: transcript) }
  let(:transcript) { FactoryHelpers.upload_file('spec/factories/csv/test_empty.csv', 'text/csv', true) }

  let(:headers) { user.create_new_auth_token }
  let(:request) { get generated_conversations_transcript_v1_intervention_path(intervention.id), headers: headers }
  let(:intervention_owner) { admin }
  let(:user) { researcher }
  let(:action_path) do
    ENV.fetch('APP_HOSTNAME', nil) + Rails.application.routes.url_helpers.rails_blob_path(intervention.conversations_transcript, only_path: true)
  end

  context 'when owner of the intervention wants to fetch the intervention csv' do
    before { request }

    it 'returns OK' do
      expect(response).to have_http_status(:found)
    end

    it 'return correct body' do
      expect(response).to redirect_to(action_path)
    end
  end

  context 'collaborator without access data' do
    let(:user) { intervention.collaborators.first.user }

    before { request }

    it 'returns forbidden' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'collaborator with access' do
    let(:user) { intervention.collaborators.first.user }

    before do
      intervention.collaborators.first.update!(data_access: true)
      request
    end

    it 'returns OK' do
      expect(response).to have_http_status(:found)
    end
  end
end
