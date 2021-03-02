# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sms_plans/:sms_plan_id/variants/:id', type: :request do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
  let!(:variant_id) { variant.id }
  let(:request) { delete v1_sms_plan_variant_path(sms_plan_id: sms_plan.id, id: variant_id), headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when variant with given id exists' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'destroy variant' do
      expect { request }.to change(SmsPlan::Variant, :count).by(-1)
    end
  end

  context 'when variant with given id does not exist' do
    let(:variant_id) { 'non-existing' }

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end

    it 'does not create variant' do
      expect { request }.not_to change(SmsPlan::Variant, :count)
    end
  end

  context 'when user without access for variant' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }

    it 'returns 404' do
      request
      expect(response).to have_http_status(:not_found)
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
