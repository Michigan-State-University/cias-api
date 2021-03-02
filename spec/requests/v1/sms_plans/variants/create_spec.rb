# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_plans/:sms_plan_id/variants', type: :request do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create(:sms_plan, session: session) }
  let(:request) { post v1_sms_plan_variants_path(sms_plan_id: sms_plan.id), params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:params) do
      {
        variant: {
          formula_match: '< 2',
          content: 'some content for sms'
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new variant with proper data' do
      expect { request }.to change(SmsPlan::Variant, :count).by(1)

      expect(sms_plan.variants.last).to have_attributes(
        formula_match: '< 2',
        content: 'some content for sms'
      )
    end
  end

  context 'when params are invalid' do
    let(:params) { { variant: {} } }

    it 'does not create new sms plan returns :bad_request status' do
      expect { request }.not_to change(SmsPlan::Variant, :count)
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

  context 'when intervention was published' do
    let(:intervention) { create(:intervention, :published) }
    let(:session) { create(:session, intervention: intervention) }
    let(:params) { {} }

    it 'returns 405 status' do
      expect { request }.not_to change(SmsPlan::Variant, :count)
      expect(response).to have_http_status(:method_not_allowed)
    end
  end
end
