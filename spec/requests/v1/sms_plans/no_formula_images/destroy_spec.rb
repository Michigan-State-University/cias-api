# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sms_plans/:sms_plan_id/no_formula_image', type: :request do
  let(:request) { delete v1_sms_plan_no_formula_image_path(sms_plan_id), headers: headers }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, :with_no_formula_image, session: session) }
  let(:sms_plan_id) { sms_plan.id }

  context 'when everything was processed correctly' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'purge image' do
      request
      expect(sms_plan.reload.no_formula_image.attached?).to be(false)
    end
  end

  context 'when intervention is published' do
    let(:intervention) { create(:intervention, status: :published) }

    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  context 'when sms plan with given id does not exist' do
    let(:sms_plan_id) { 'non-existing' }

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when researcher wants to delete an image in not belongs to him session' do
    let(:user) { create(:user, :confirmed, :researcher) }

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
