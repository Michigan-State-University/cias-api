# frozen_string_literal: true

RSpec.describe 'DELETE /v1/live_chat/intervention/:id/navigator_setups/files/:file_id', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }
  let(:file_id) { intervention.navigator_setup.participant_files.first.id }
  let(:headers) { user.create_new_auth_token }

  let(:request) do
    delete v1_live_chat_intervention_navigator_setups_file_path(id: intervention.id, file_id: file_id),
           headers: headers
  end

  before do
    intervention.navigator_setup.participant_files.attach(file)
    request
  end

  context 'correctly deletes files' do
    it 'returns correct status code' do
      expect(response).to have_http_status(:no_content)
    end

    it 'correctly deletes the file' do
      expect(intervention.navigator_setup.reload.participant_files.length).to be 0
    end
  end

  context 'file does not exist' do
    let(:file_id) { 'gkjsahgkjs' }

    it 'returns correct status code (not found)' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'no access' do
    let(:other_user) { create(:user, :researcher, :confirmed) }
    let(:headers) { other_user.create_new_auth_token }

    it 'returns correct status code (not found)' do
      expect(response).to have_http_status(:not_found)
    end
  end
end
