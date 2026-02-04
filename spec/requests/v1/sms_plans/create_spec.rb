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
          is_used_formula: false,
          type: 'SmsPlan::Normal'
        }
      }
    end

    context 'researcher' do
      let(:user) { create(:user, :confirmed, :researcher) }
      let!(:intervention) { create(:intervention, user: user) }

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end
    end

    context 'user_with_multiple_roles' do
      let(:user) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
      let!(:intervention) { create(:intervention, user: user) }

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end
    end

    context 'team admin' do
      let(:user) { create(:user, :confirmed, :team_admin) }
      let!(:intervention) { create(:intervention, user: user) }

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end
    end

    context 'admin' do
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

    context 'for sms alerts' do
      let(:params) do
        {
          sms_plan: {
            name: 'sms plan 1',
            session_id: session.id,
            schedule: SmsPlan.schedules[:after_session_end],
            frequency: SmsPlan.frequencies[:once_a_day],
            no_formula_text: 'test text',
            is_used_formula: false,
            type: 'SmsPlan::Alert'
          }
        }
      end

      it 'correctly creates SMS Alert plan' do
        request
        expect(response).to have_http_status(:created)
      end
    end

    context 'with defined specific_time sms_send_time_type' do
      let(:params) do
        {
          sms_plan: {
            name: 'sms plan with specific time',
            session_id: session.id,
            schedule: SmsPlan.schedules[:after_session_end],
            frequency: SmsPlan.frequencies[:once],
            no_formula_text: 'test text',
            is_used_formula: false,
            type: 'SmsPlan::Normal',
            sms_send_time_type: 'specific_time',
            sms_send_time_details: { time: '14:30' }
          }
        }
      end

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates sms plan with specific_time type' do
        expect { request }.to change(SmsPlan, :count).by(1)
        expect(SmsPlan.find(response.parsed_body['data']['id'])).to have_attributes(
          sms_send_time_type: 'specific_time',
          sms_send_time_details: { 'time' => '14:30' }
        )
      end

      it 'returns correct data in response' do
        request

        expect(json_response['data']['attributes']).to include(
          'sms_send_time_type' => 'specific_time',
          'sms_send_time_details' => { 'time' => '14:30' }
        )
      end
    end

    context 'when creating sms plan with time_range type' do
      let(:params) do
        {
          sms_plan: {
            name: 'sms plan with time range',
            session_id: session.id,
            schedule: SmsPlan.schedules[:after_session_end],
            frequency: SmsPlan.frequencies[:once],
            no_formula_text: 'test text',
            is_used_formula: false,
            type: 'SmsPlan::Normal',
            sms_send_time_type: 'time_range',
            sms_send_time_details: { from: '9', to: '17' }
          }
        }
      end

      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates sms plan with time_range type' do
        expect { request }.to change(SmsPlan, :count).by(1)

        expect(SmsPlan.find(response.parsed_body['data']['id'])).to have_attributes(
          sms_send_time_type: 'time_range',
          sms_send_time_details: { 'from' => '9', 'to' => '17' }
        )
      end

      it 'returns correct data in response' do
        request

        expect(json_response['data']['attributes']).to include(
          'sms_send_time_type' => 'time_range',
          'sms_send_time_details' => { 'from' => '9', 'to' => '17' }
        )
      end
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
