# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/short_links/verify', type: :request do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, :published, user: researcher) }
  let!(:short_link) { create(:short_link, linkable: intervention, name: 'short-link') }
  let(:params) { { slug: 'short-link' } }
  let(:user) { participant }
  let(:request) do
    post v1_verify_short_links_path, params: params, headers: user.create_new_auth_token
  end

  context 'sequential intervention with sessions' do
    let!(:session) { create(:session, intervention: intervention) }

    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                session_id: session.id,
                                                                health_clinic_id: nil,
                                                                multiple_fill_session_available: false,
                                                                user_intervention_id: nil
                                                              })
    }
  end

  context 'without token' do
    let(:request) do
      post v1_verify_short_links_path, params: params
    end

    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }
  end

  context 'sequential intervention with open sessions' do
    let!(:session) { create(:session, intervention: intervention) }
    let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
    let!(:user_session) { create(:user_session, session: session, user: participant, user_intervention: user_intervention) }

    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                session_id: session.id,
                                                                health_clinic_id: nil,
                                                                multiple_fill_session_available: false,
                                                                user_intervention_id: user_intervention.id
                                                              })
    }
  end

  context 'when intervention is draft' do
    let(:intervention) { create(:intervention, user: researcher) }

    before do
      request
    end

    it { expect(response).to have_http_status(:bad_request) }

    it {
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_DRAFT' } })
    }
  end

  context 'when intervention is archived/closed' do
    let(:intervention) { create(:intervention, :closed, user: researcher) }

    before do
      request
    end

    it { expect(response).to have_http_status(:bad_request) }

    it {
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_CLOSED' } })
    }
  end

  context 'when intervention is paused' do
    let(:intervention) { create(:intervention, :paused, user: researcher) }

    before do
      request
    end

    it { expect(response).to have_http_status(:bad_request) }

    it {
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_PAUSED' } })
    }
  end

  context 'quest without access' do
    let(:user) { create(:user, :guest, :confirmed) }
    let(:intervention) { create(:intervention, :published, user: researcher, shared_to: 'registered') }

    before do
      request
    end

    it { expect(response).to have_http_status(:unauthorized) }

    it {
      expect(json_response).to include({ 'message' => 'Interventions can only be completed by a registered user',
                                         'details' => { 'reason' => 'ONLY_REGISTERED' } })
    }
  end

  context 'participant without access' do
    let(:intervention) { create(:intervention, :published, user: researcher, shared_to: 'invited') }

    before do
      request
    end

    it { expect(response).to have_http_status(:forbidden) }

    it {
      expect(json_response).to include({ 'message' => 'Interventions can only be completed by a invited user', 'details' => { 'reason' => 'ONLY_INVITED' } })
    }
  end

  context 'sequential intervention without sessions' do
    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                health_clinic_id: nil,
                                                                session_id: nil,
                                                                multiple_fill_session_available: false,
                                                                user_intervention_id: nil
                                                              })
    }
  end

  context 'sequential module intervention with sessions' do
    let(:intervention) { create(:flexible_order_intervention, :published, user: researcher) }
    let!(:session) { create(:session, intervention: intervention) }

    before do
      request
    end

    it { expect(response).to have_http_status(:ok) }

    it {
      expect(json_response['data'].symbolize_keys).to include({
                                                                intervention_id: intervention.id,
                                                                health_clinic_id: nil,
                                                                session_id: nil,
                                                                multiple_fill_session_available: false,
                                                                user_intervention_id: nil
                                                              })
    }
  end
end
