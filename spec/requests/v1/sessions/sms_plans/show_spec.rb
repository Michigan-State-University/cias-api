# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:session_id/sms_plans', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_session_sms_plans_path(session_id: session.id), headers: headers }
  let!(:sms_plan_1) { create(:sms_plan, session: session) }
  let!(:sms_plan_2) { create(:sms_plan, session: session) }


  it 'returns sms plans for session' do
    request

    expect(response).to have_http_status(:ok)
    expect(json_response['data'][0]['id']).to eq sms_plan_1.id
    expect(json_response['data'][1]['id']).to eq sms_plan_2.id
  end
end
