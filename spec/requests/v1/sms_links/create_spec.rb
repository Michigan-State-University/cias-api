# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_plans/:sms_plan_id/sms_links', type: :request do
  let(:sms_plan) { create(:sms_plan, no_formula_text: no_formula_text) }
  let(:request) { post v1_sms_plan_sms_links_path(sms_plan.id), params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:no_formula_text) { 'Test link: .:link1:.' }
    let(:params) do
      {
        sms_link: {
          url: 'test.com',
          type: 'website',
          sms_plan_id: sms_plan.id
        }
      }
    end

    it 'returns :created status' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates new sms link with proper data' do
      expect { request }.to change(SmsLink, :count).by(1)

      expect(SmsLink.last).to have_attributes(
        url: 'test.com',
        type: 'website',
        sms_plan_id: sms_plan.id,
        session_id: sms_plan.session.id,
        variable_number: 1
      )
    end
  end
end
