# frozen_string_literal: true

RSpec.describe 'PATCH /v1/live_chat/intervention/:id/navigator_setups', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }

  let(:request) do
    patch v1_live_chat_intervention_navigator_setup_path(id: intervention.id), headers: headers, params: params
  end

  context 'correctly updates navigator setup' do
    let(:params) do
      {
        navigator_setup: {
          contact_email: 'mike.wazowski@monsters-inc.com',
          no_navigator_available_message: 'No navigators available at the moment'
        }
      }
    end

    it 'returns correct status code (OK)' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'correctly updates setup attributes' do
      request
      setup = intervention.navigator_setup.reload
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
        request
        phone = intervention.navigator_setup.phone
        expect(phone).not_to be nil
        expect(phone.number).to eq 111_111_111.to_s
        expect(phone.iso).to eq 'US'
        expect(phone.prefix).to eq '+1'
      end
    end

    context 'correctly updates phone object' do
      let!(:intervention) { create(:intervention, :with_navigator_setup_and_phone, user: user) }

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
        request
        phone = intervention.navigator_setup.reload.phone
        expect(phone.number).to eq 111_222_333.to_s
        expect(phone.iso).to eq 'PL'
        expect(phone.prefix).to eq '+43'
      end
    end

    context 'Script template upload' do
      let(:file) { FactoryHelpers.upload_file('spec/factories/csv/test_empty.csv', 'text/csv', false) }

      context 'Correctly uploads file' do
        let(:params) do
          {
            navigator_setup: {
              filled_script_template: file
            }
          }
        end

        it 'returns correct status code (OK)' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'has a file assigned' do
          request
          expect(intervention.navigator_setup.reload.filled_script_template.attached?).to be true
        end

        it 'returns correct file data' do
          request
          expect(json_response['data']['attributes']['filled_script_template']).to include(
            {
              'id' => intervention.navigator_setup.reload.filled_script_template.id,
              'name' => include('test_empty.csv'),
              'url' => include(polymorphic_url(intervention.navigator_setup.filled_script_template).sub('http://www.example.com/', ''))
            }
          )
        end
      end

      context 'Deletes file when sent nil' do
        let(:params) do
          {
            navigator_setup: {
              filled_script_template: nil
            }
          }
        end

        before do
          intervention.navigator_setup.filled_script_template.attach(file)
        end

        it 'returns correct status code (OK)' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'correctly deletes previous file' do
          request
          expect(intervention.navigator_setup.reload.filled_script_template.attached?).to eq false
          expect(ActiveStorage::Attachment.count).to be 0
        end
      end
    end
  end

  context 'sets phone to nil when phone sent as nil and phone is present' do
    let!(:intervention) { create(:intervention, :with_navigator_setup_and_phone, user: user) }

    let(:params) do
      {
        navigator_setup: {
          phone: nil
        }
      }
    end

    it do
      request
      expect(intervention.navigator_setup.reload.phone).to be nil
      expect(Phone.count).to eq 0
    end
  end

  context 'when params invalid' do
    let(:params) { {} }

    it do
      request
      expect(response).to have_http_status(:bad_request)
    end
  end
end
