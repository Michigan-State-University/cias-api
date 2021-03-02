# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sms_plans/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_sms_plan_path(id: sms_plan_id), headers: headers }

  context 'when there is a sms plan with given id' do
    let!(:sms_plan) { create(:sms_plan) }
    let!(:variant) { create(:sms_plan_variant, sms_plan: sms_plan) }
    let!(:sms_plan_id) { sms_plan.id }

    before do
      request
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns sms plan with variant data' do
      expect(json_response['data']).to include(
        'id' => sms_plan_id.to_s,
        'type' => 'sms_plan',
        'attributes' => include('name' => sms_plan.name)
      )
      expect(json_response['included']).to include(
        'id' => variant.id,
        'type' => 'variant',
        'attributes' => include(
          'formula_match' => variant.formula_match,
          'content' => variant.content
        )
      )
    end
  end

  context 'when there is no sms plan with given id' do
    let!(:sms_plan_id) { 'invalid id' }

    it 'has correct http code :not_found' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
