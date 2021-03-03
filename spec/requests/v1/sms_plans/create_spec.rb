# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_plans', type: :request do
  let(:request) { post v1_sms_plans_path, params: params, headers: headers }
  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let!(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }

  context 'when params are valid' do
    let(:params) do
      {
        sms_plan: {
          name: 'sms plan 1',
          session_id: session.id,
          schedule: SmsPlan.schedules[:after_session_end],
          frequency: SmsPlan.frequencies[:once_a_day],
          no_formula_text: 'test text',
          is_used_formula: false
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new sms plan with proper data' do
      expect { request }.to change(SmsPlan, :count).by(1)

      expect(SmsPlan.last).to have_attributes(
        name: 'sms plan 1',
        session: session,
        schedule: SmsPlan.schedules[:after_session_end],
        frequency: SmsPlan.frequencies[:once_a_day],
        is_used_formula: false,
        no_formula_text: 'test text'
      )
    end
  end

  context 'when params are invalid' do
    let(:params) { { sms_plan: {} } }

    it 'does not create new sms plan returns :bad_request status' do
      expect { request }.not_to change(SmsPlan, :count)
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'when user is participant' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }
    let(:params) { {} }

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end

  context 'when researcher want to create sms plan for session of another researcher' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:another_user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let!(:intervention) { create(:intervention, user: another_user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:params) do
      {
        sms_plan: {
          name: 'sms plan 1',
          session_id: session.id,
          schedule: SmsPlan.schedules[:after_session_end],
          frequency: SmsPlan.frequencies[:once_a_day]
        }
      }
    end

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end

  context 'when intervention was published' do
    let(:intervention) { create(:intervention, :published) }
    let(:session) { create(:session, intervention: intervention) }
    let(:params) do
      {
        sms_plan: {
          name: 'sms plan 1',
          session_id: session.id,
          schedule: SmsPlan.schedules[:after_session_end],
          frequency: SmsPlan.frequencies[:once_a_day]
        }
      }
    end

    it 'returns 405 status' do
      expect { request }.not_to change(SmsPlan, :count)
      expect(response).to have_http_status(:method_not_allowed)
    end
  end
end
