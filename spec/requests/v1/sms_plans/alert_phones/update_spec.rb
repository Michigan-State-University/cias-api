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

    context 'when phone contains non-permitted attributes' do
      let(:other_user) { create(:user, :confirmed, :participant) }
      let!(:original_user_id) { phone.user_id }
      let(:params) { { phone: { iso: 'US', user_id: other_user.id, confirmed: false } } }

      it 'updates only permitted attributes' do
        expect(response).to have_http_status(:ok)
        expect(phone.reload).to have_attributes(iso: 'US', user_id: original_user_id, confirmed: true)
      end
    end

    context 'when phone has no permitted attributes' do
      let(:params) { { phone: { confirmed: false } } }

      it 'returns bad request and does not change the phone' do
        expect(response).to have_http_status(:bad_request)
        expect(phone.reload.confirmed).to be true
      end
    end
  end

  context 'when the phone is not on the plan' do
    let!(:other_phone) { create(:phone, :confirmed) }
    let(:request) do
      patch v1_sms_plan_phone_path(sms_plan_id: sms_alert.id, id: other_phone.id), headers: headers, params: params
    end

    it 'returns :not_found and changes nothing' do
      pending 'BUG: update/destroy of an alert phone looks the phone up with find_by on the plan alert phones and calls .phone ' \
              'on the nil result, so a phone that is not on the plan answers 500 instead of 404 (T-17)'

      expect { request }.not_to change { other_phone.reload.attributes }
      expect(response).to have_http_status(:not_found)
    end
  end
end
