# frozen_string_literal: true

RSpec.describe 'DELETE /v1/sms_plans/:sms_plan_id/alert_phones/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let!(:intervention) { create(:intervention, user: user) }
  let!(:session) { create(:session, intervention: intervention) }
  let!(:sms_alert) { create(:sms_plan, type: 'SmsPlan::Alert', session: session) }
  let!(:phone) { create(:phone, :confirmed, sms_plans: [sms_alert]) }
  let(:headers) { user.create_new_auth_token }

  let(:request) do
    delete v1_sms_plan_phone_path(sms_plan_id: sms_alert.id, id: sms_alert.alert_phones.first.phone.id), headers: headers
  end

  context 'correctly deletes the alert phone associated record' do
    before { request }

    it 'returns correct HTTP status code (No Content)' do
      expect(response).to have_http_status(:no_content)
    end

    it 'deletes alert phone record' do
      expect(AlertPhone.count).to be 0
    end
  end
end
