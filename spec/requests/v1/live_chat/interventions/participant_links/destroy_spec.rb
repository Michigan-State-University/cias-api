# frozen_string_literal: true

RSpec.describe 'DELETE /v1/live_chat/intervention/:id/navigator_setups/participant_links/:participant_link_id', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }
  let!(:participant_link) do
    LiveChat::Interventions::ParticipantLink.create!(
      navigator_setup: intervention.navigator_setup, url: 'https://google.com', display_name: 'This is my favourite website'
    )
  end
  let(:request) do
    delete v1_live_chat_intervention_navigator_setups_participant_link_path(id: intervention.id, participant_link_id: participant_link.id),
           headers: headers
  end

  context 'correctly updates participant link' do
    it 'returns correct status code (OK)' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'remove link from db' do
      expect { request }.to change(LiveChat::Interventions::ParticipantLink, :count).by(-1)
    end
  end

  context 'when researcher want to destroy the link from other researcher intervention' do
    let(:researcher) { create(:user, :researcher, :confirmed) }
    let(:headers) { researcher.create_new_auth_token }

    it 'return correct status and msg' do
      request
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include("Couldn't find Intervention with 'id'=#{intervention.id}")
    end
  end

  context 'when user has not researcher role' do
    let(:participant) { create(:user, :participant, :confirmed) }
    let(:headers) { participant.create_new_auth_token }

    it 'return correct status and msg' do
      request
      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end
end
