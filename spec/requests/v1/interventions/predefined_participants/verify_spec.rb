# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/predefined_participants/verify', type: :request do
  let(:request) do
    post v1_verify_predefined_participant_path, params: params
  end
  let(:user) { create(:user, :predefined_participant, :with_phone) }
  let(:params) do
    {
      slug: user.predefined_user_parameter.slug
    }
  end

  it 'when the slug is correct but intervention is draft' do
    request
    expect(response).to have_http_status(:bad_request)
    expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_DRAFT' } })
  end

  context 'when intervention is paused' do
    before do
      user.predefined_user_parameter.intervention.update!(status: :paused)
    end

    it 'returns correct status and error message' do
      request
      expect(response).to have_http_status(:bad_request)
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_PAUSED' } })
    end
  end

  context 'when intervention is closed/archived' do
    before do
      user.predefined_user_parameter.intervention.update!(status: :closed)
    end

    it 'returns correct status and error message' do
      request
      expect(response).to have_http_status(:bad_request)
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_CLOSED' } })
    end
  end

  context 'when intervention is published' do
    before do
      user.predefined_user_parameter.intervention.published!
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'return correct body' do
      request
      expect(json_response.keys).to match_array(%w[user redirect_data])
    end

    it 'return data about the user' do
      request
      expect(json_response['user'].keys).to match_array(%w[id type attributes])
      expect(json_response['user']['attributes'].keys).to match_array(%w[id
                                                                         email
                                                                         full_name
                                                                         first_name
                                                                         last_name
                                                                         description
                                                                         sms_notification
                                                                         time_zone
                                                                         active
                                                                         roles
                                                                         avatar_url
                                                                         phone
                                                                         team_id
                                                                         admins_team_ids
                                                                         feedback_completed
                                                                         email_notification
                                                                         organizable_id
                                                                         quick_exit_enabled
                                                                         team_name
                                                                         health_clinics_ids])
    end

    it 'return information needed to redirect the user' do
      request
      expect(json_response['redirect_data'].keys).to match_array(%w[intervention_id session_id health_clinic_id multiple_fill_session_available
                                                                    user_intervention_id lang])
    end
  end

  context 'when slug is incorrect' do
    let(:params) do
      {
        slug: 'wrong_slug'
      }
    end

    it 'when the slug is correct but intervention is draft' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when a participant tries to perform a request' do
    let(:participant) { create(:user, :participant, :confirmed) }
    let!(:headers) { participant.create_new_auth_token }
    let(:request) do
      post v1_verify_predefined_participant_path, params: params, headers: headers
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
