# frozen_string_literal: true

require 'rails_helper'
require 'support/predefined_participant_sms_helpers'

RSpec.describe 'GET /v1/interventions/:intervention_id/predefined_participants/sms_campaigns/meta', type: :request do
  include PredefinedParticipantSmsHelpers

  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let!(:intervention) { create(:intervention, :published, user: researcher) }
  let(:path) { "/v1/interventions/#{intervention.id}/predefined_participants/sms_campaigns/meta" }
  let(:request) { get path, headers: current_user.create_new_auth_token }
  let(:web_host) { 'https://web.example.test' }

  before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_host)) }

  describe 'payload' do
    before { request }

    it 'answers 200' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns exactly the documented keys at the top level' do
      expect(response).to have_http_status(:ok)
      expect(json_response.keys).to match_array(%w[personal_link_template personal_link_expected_length tracked_link_template
                                                   tracked_link_expected_length gsm7_segment_lengths ucs2_segment_lengths
                                                   max_body_length max_segments max_reminder_days_after])
    end

    it 'returns the maximum days_after of a scheduled reminder' do
      expect(json_response['max_reminder_days_after']).to eq(60)
    end

    it 'returns the GSM-7 segment lengths [160, 153] literally' do
      expect(response).to have_http_status(:ok)
      expect(json_response['gsm7_segment_lengths']).to eq([160, 153])
    end

    it 'returns the UCS-2 segment lengths [70, 67] literally' do
      expect(response).to have_http_status(:ok)
      expect(json_response['ucs2_segment_lengths']).to eq([70, 67])
    end

    it 'returns the personal link template built from WEB_URL' do
      expect(response).to have_http_status(:ok)
      expect(json_response['personal_link_template']).to eq("#{web_host}/usr/:slug")
    end

    it 'returns the tracked link template built from WEB_URL' do
      expect(response).to have_http_status(:ok)
      expect(json_response['tracked_link_template']).to eq("#{web_host}/link/:slug")
    end

    it 'returns the personal link length with the capped base58(8) slug' do
      expect(response).to have_http_status(:ok)
      expect(json_response['personal_link_expected_length']).to eq("#{web_host}/usr/".length + 8)
    end

    it 'returns the tracked link length with the capped base58(9) slug' do
      expect(response).to have_http_status(:ok)
      expect(json_response['tracked_link_expected_length']).to eq("#{web_host}/link/".length + 9)
    end

    it 'is not swallowed by predefined_participants#show' do
      expect(response).to have_http_status(:ok)
      expect(json_response).not_to have_key('message')
    end
  end

  describe 'authentication' do
    it 'answers 401 without a token' do
      get path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'role checks' do
    it_behaves_like 'users without access'
  end

  describe 'current editor gate' do
    let(:collaborator) { create(:user, :researcher, :confirmed) }

    before do
      create(:collaborator, intervention: intervention, user: collaborator, edit: true, view: true)
    end

    it 'answers 403 to a collaborator with edit: true who is not the current editor' do
      intervention.update!(current_editor: researcher)
      get path, headers: collaborator.create_new_auth_token
      expect(response).to have_http_status(:forbidden)
    end

    it 'the same collaborator gets 200 once they are the current editor' do
      intervention.update!(current_editor: collaborator)
      get path, headers: collaborator.create_new_auth_token
      expect(response).to have_http_status(:ok)
    end
  end
end
