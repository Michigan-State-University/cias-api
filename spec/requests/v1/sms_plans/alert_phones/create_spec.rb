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

    context 'when FE adds a placeholder phone with blank number' do
      # cias-web creates the phone first and fills the number later through update
      let(:params) { { phone: { prefix: '+1', iso: 'US', number: '' } } }

      it 'creates a confirmed phone' do
        expect { request }.to change(Phone, :count).by 1
        expect(response).to have_http_status(:created)
        expect(Phone.last).to have_attributes(prefix: '+1', iso: 'US', confirmed: true)
      end
    end

    context 'when phone contains non-permitted attributes' do
      let(:other_user) { create(:user, :confirmed, :participant) }
      let(:params) { { phone: { iso: 'pl', prefix: '+48', number: '765876987', user_id: other_user.id, confirmed: false } } }

      it 'ignores them' do
        request
        expect(response).to have_http_status(:created)
        expect(Phone.last).to have_attributes(user_id: nil, confirmed: true)
      end
    end

    context 'when phone has no permitted attributes' do
      let(:params) { { phone: { confirmed: false } } }

      it 'returns bad request and does not create a phone' do
        expect { request }.not_to change(Phone, :count)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
