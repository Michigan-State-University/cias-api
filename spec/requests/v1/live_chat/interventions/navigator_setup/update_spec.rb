# frozen_string_literal: true

RSpec.describe 'PATCH /v1/live_chat/intervention/:id/navigator_setups', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }

  let(:request) do
    patch v1_live_chat_intervention_navigator_setup_path(id: intervention.id), headers: headers, params: params
  end

  before { request }

  context 'correctly updates navigator setup' do
    let(:params) do
      {
        navigator_setup: {
          is_navigator_notification_on: false,
          contact_email: 'mike.wazowski@monsters-inc.com',
          no_navigator_available_message: 'No navigators available at the moment'
        }
      }
    end

    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'correctly updates setup attributes' do
      setup = intervention.navigator_setup.reload
      expect(setup.is_navigator_notification_on).to eq false
      expect(setup.contact_email).to eq 'mike.wazowski@monsters-inc.com'
      expect(setup.no_navigator_available_message).to eq 'No navigators available at the moment'
    end

    context 'correctly assigns phone object' do
      let(:params) do
        {
          navigator_setup: {
            phone: {
              number: 111_111_111,
              iso: 'US',
              prefix: '+1'
            }
          }
        }
      end

      it do
        phone = intervention.navigator_setup.phone
        expect(phone).not_to be nil
        expect(phone.number).to eq 111_111_111.to_s
        expect(phone.iso).to eq 'US'
        expect(phone.prefix).to eq '+1'
      end
    end

    context 'correctly updates phone object' do
      let(:nav_setup) do
        navigator_setup = intervention.navigator_setup
        navigator_setup.update!(phone: Phone.new(iso: 'US', prefix: '+48', number: '111111111'))
        navigator_setup
      end

      let(:params) do
        {
          navigator_setup: {
            phone: {
              number: 111_222_333,
              iso: 'PL',
              prefix: '+43'
            }
          }
        }
      end

      it do
        phone = intervention.navigator_setup.phone
        expect(phone.number).to eq 111_222_333.to_s
        expect(phone.iso).to eq 'PL'
        expect(phone.prefix).to eq '+43'
      end
    end
  end

  context 'when params invalid' do
    let(:params) { {} }

    it do
      expect(response).to have_http_status(:bad_request)
    end
  end
end
