# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/sms_plans/:id', type: :request do
  let(:request) { patch v1_sms_plan_path(sms_plan.id), params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create :sms_plan, session: session }
  let(:params) do
    {
      sms_plan: {
        name: 'new name'
      }
    }
  end

  context 'valid params' do
    it 'returns :ok status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'updates sms plan attributes' do
      expect { request }.to change { sms_plan.reload.name }.from(sms_plan.name).to('new name').and \
        avoid_changing { SmsPlan.count }
    end
  end

  context 'invalid params' do
    let(:params) { { sms_plan: {} } }

    it 'returns :bad_request status' do
      request
      expect(response).to have_http_status(:bad_request)
    end

    it 'does not update team attributes' do
      expect { request }.not_to change(sms_plan, :name)
    end
  end

  context 'when intervention was published' do
    let(:intervention) { create(:intervention, :published) }
    let(:session) { create(:session, intervention: intervention) }

    it 'returns 405 status' do
      expect { request }.not_to change(sms_plan, :name)
      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  context 'when researcher want to update sms plan with session of another researcher' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:another_user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let!(:intervention) { create(:intervention, user: another_user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:params) do
      {
        sms_plan: {
          session_id: session.id
        }
      }
    end

    it 'returns :forbidden status and not authorized message' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq('You are not authorized to access this page.')
    end
  end
end
