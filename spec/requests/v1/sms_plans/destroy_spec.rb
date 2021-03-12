# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sms_plans/:id', type: :request do
  let(:request) { delete v1_sms_plan_path(sms_plan_id), headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let(:sms_plan_id) { sms_plan.id }

  context 'when sms plan with given id exists' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'destroys a sms plan' do
      expect { request }.to change(SmsPlan, :count).by(-1)
    end
  end

  context 'when sms plan with given id does not exist' do
    let(:sms_plan_id) { 'non-existing' }

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end

    it 'does not create a new sms plan' do
      expect { request }.not_to change(SmsPlan, :count)
    end
  end

  context 'when intervention was published' do
    let(:intervention) { create(:intervention, :published) }
    let(:session) { create(:session, intervention: intervention) }

    it 'returns 405 status' do
      expect { request }.not_to change(SmsPlan, :count)
      expect(response).to have_http_status(:method_not_allowed)
    end
  end
end
