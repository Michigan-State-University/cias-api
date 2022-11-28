# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:id/generate_conversations_transcript', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:intervention) { create(:intervention, user: admin, live_chat_enabled: true) }

  let(:request) do
    post generate_conversations_transcript_v1_intervention_path(id: intervention.id), headers: user.create_new_auth_token
  end

  before { request }

  context 'authorized user' do
    it 'returns correct status code (200, OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'enqueues correct job' do
      expect(LiveChat::GenerateTranscriptJob).to have_been_enqueued.once
    end
  end

  context 'unauthorized user' do
    %i[participant guest navigator].each do |role|
      let(:user) { create(:user, :confirmed, role) }

      it 'returns correct status code' do
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
