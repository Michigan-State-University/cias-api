# frozen_string_literal: true

RSpec.describe 'PATCH /v1/sms_plans/:sms_plan_id/alert_phones/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention, user: user) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:sms_alert) { create(:sms_plan, type: 'SmsPlan::Alert', session: session) }
  let!(:phone) { create(:phone, :confirmed, sms_plans: [sms_alert]) }
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

  let(:request) do
    patch v1_sms_plan_phone_path(sms_plan_id: sms_alert.id, id: phone.id), headers: headers, params: params
  end

  context 'correctly updates alert phone data' do
    before { request }

    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'correctly updates phone data' do
      expect(phone.reload).to have_attributes(**params[:phone])
    end

    context 'wrong params' do
      let(:params) { {} }

      it 'returns correct HTTP status code (Bad Request)' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
