# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/intervention/:id/navigator_helping_materials', type: :request do
  let(:user) { create(:user, :navigator, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let!(:navigator_link) do
    LiveChat::Interventions::Link.create!(
      navigator_setup: intervention.navigator_setup, url: 'https://google.com', display_name: 'This is my favourite website', link_for: 'navigators'
    )
  end
  let(:file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_live_chat_intervention_navigator_helping_materials_path(id: intervention.id), headers: headers
  end

  before do
    intervention.navigator_setup.navigator_files.attach(file)
    request
  end

  context 'correctly fetches setup data' do
    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data' do
      expect(json_response['data']['attributes']['navigator_files'].size).to eq(1)
      expect(p(json_response['data']['relationships']['navigator_links'].size)).to eq(1)
    end
  end

  context 'when user without permission' do
    let(:participant) { create(:user, :participant, :confirmed) }
    let(:headers) { participant.create_new_auth_token }

    it 'returns correct status code (403)' do
      expect(response).to have_http_status(:forbidden)
    end

    it 'return error message' do
      expect(json_response['message']).to include('You are not authorized to access this page.')
    end
  end
end
