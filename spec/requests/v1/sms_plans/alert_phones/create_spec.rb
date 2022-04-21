# frozen_string_literal: true

RSpec.describe 'POST /v1/sms_plans/:sms_plan_id/alert_phones/', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_alert) { create(:sms_plan, type: 'SmsPlan::Alert', session: session) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      phone: {
        iso: 'pl',
        prefix: '+48',
        number: '765876987'
      }
    }
  end

  let(:request) { post v1_sms_plan_phones_path(sms_plan_id: sms_alert.id), headers: headers, params: params }

  context 'correctly creates associations' do
    it 'returns correct HTTP status code (Created)' do
      request
      expect(response).to have_http_status(:created)
    end

    it 'creates a new phone number' do
      expect { request }.to change(Phone, :count).by 1
    end

    it 'creates associtations records for alert phones' do
      expect { request }.to change(AlertPhone, :count).by 1
    end

    context 'wrong params' do
      let(:params) { {} }

      it 'returns correct HTTP status code (Bad Request)' do
        request
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
