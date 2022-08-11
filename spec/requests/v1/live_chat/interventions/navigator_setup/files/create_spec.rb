# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/live_chat/intervention/:id/navigator_setups/files', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }

  let(:params) do
    {
      navigator_setup: {
        files_for: 'participants',
        files: [file]
      }
    }
  end

  let(:request) do
    post v1_live_chat_intervention_navigator_setups_files_path(intervention.id),
         headers: user.create_new_auth_token, params: params
  end

  before { request }

  context 'correctly uploads files' do
    let(:file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }

    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct file data' do
      file_data = json_response['data']['attributes']['participant_files']
      expect(file_data.length).to eq 1
      expect(intervention.navigator_setup.participant_files.length).to eq 1
      expect(file_data[0]['name']).to include('test_image_1.jpg')
      expect(file_data[0]['url']).to include(polymorphic_url(intervention.navigator_setup.participant_files.first).sub('http://www.example.com/', ''))
      expect(file_data[0]['id']).to eq intervention.navigator_setup.participant_files.first.id
    end

    context 'for navigators' do
      let(:params) do
        {
          navigator_setup: {
            files_for: 'navigators',
            files: [file]
          }
        }
      end

      it 'returns correct status code (OK)' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct file data' do
        file_data = json_response['data']['attributes']['navigator_files']
        expect(file_data.length).to eq 1
        expect(intervention.navigator_setup.navigator_files.length).to eq 1
        expect(file_data[0]['name']).to include('test_image_1.jpg')
        expect(file_data[0]['url']).to include(polymorphic_url(intervention.navigator_setup.navigator_files.first).sub('http://www.example.com/', ''))
        expect(file_data[0]['id']).to eq intervention.navigator_setup.navigator_files.first.id
      end
    end
  end

  context 'file too big' do
    let(:file) { FactoryHelpers.upload_file('spec/factories/text/big_file.txt', 'text/plain', false) }

    it 'returns correct status code (payload too large)' do
      expect(response).to have_http_status(:payload_too_large)
    end
  end
end
