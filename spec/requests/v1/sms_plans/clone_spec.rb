# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_plan/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:session) { create(:session) }
  let(:headers) { user.create_new_auth_token }
  let!(:sms_plan) { create(:sms_plan, name: 'Plan name', session: session) }
  let!(:variants) { create_list(:sms_plan_variant, 3, sms_plan: sms_plan) }

  context 'when auth' do
    context 'is invalid' do
      before { post clone_v1_sms_plan_path(id: sms_plan.id) }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { post clone_v1_sms_plan_path(id: sms_plan.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when user clones a sms_plan' do
    before { post clone_v1_sms_plan_path(id: sms_plan.id), headers: headers }

    let(:cloned_sms_plan) { json_response['data']['attributes'] }

    it { expect(response).to have_http_status(:created) }

    it 'has correct name' do
      expect(cloned_sms_plan['name']).to eq 'Copy of Plan name'
    end

    it 'has correct number of variants' do
      expect(SmsPlan.find(json_response['data']['id']).variants.size).to eq variants.size
    end
  end
end
