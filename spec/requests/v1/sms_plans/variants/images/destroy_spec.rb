# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/sms_plans/:sms_plan_id/variants/:id/attachment', type: :request do
  let(:request) { delete attachment_v1_sms_plan_variant_path(sms_plan_id: sms_plan_id, id: variant_id), headers: headers }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_plan) { create(:sms_plan, session: session) }
  let(:sms_plan_id) { sms_plan.id }
  let!(:variant) { create(:sms_plan_variant, :with_attachment, sms_plan: sms_plan) }
  let!(:variant_id) { variant.id }

  context 'when everything was processed correctly' do
    it 'returns :no_content status' do
      request
      expect(response).to have_http_status(:no_content)
    end

    it 'purge image' do
      request
      expect(variant.reload.attachment.attached?).to be(false)
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
    let(:variant_id) { 'non-existing' }

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
