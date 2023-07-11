# frozen_string_literal: true

RSpec.describe 'PATCH /v1/live_chat/intervention/:id/navigator_setups/participant_links/:participant_link_id', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }
  let!(:participant_link) do
    LiveChat::Interventions::Link.create!(
      navigator_setup: intervention.navigator_setup, url: 'https://google.com', display_name: 'This is my favourite website'
    )
  end
  let(:request) do
    patch v1_live_chat_intervention_navigator_setups_link_path(id: intervention.id, link_id: participant_link.id),
          params: params, headers: headers
  end

  before { request }

  context 'correctly updates participant link' do
    let(:params) do
      {
        link: {
          url: 'https://bing.com',
          display_name: 'That\'s a much better search engine'
        }
      }
    end

    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'correctly updates the link' do
      link = participant_link.reload
      expect(link.display_name).to eq 'That\'s a much better search engine'
      expect(link.url).to eq 'https://bing.com'
    end
  end

  context 'only current editor can create invitations in the intervention with collaborators' do
    let(:params) do
      {
        link: {
          url: 'https://bing.com',
          display_name: 'That\'s a much better search engine'
        }
      }
    end
    let(:intervention) { create(:intervention, :with_collaborators, :with_navigator_setup, user: user, current_editor: create(:user, :researcher, :confirmed)) }

    it {
      request
      expect(response).to have_http_status(:forbidden)
    }
  end

  context 'invalid params' do
    context 'missing link data' do
      let(:params) { {} }

      it do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'url too long' do
      let(:params) do
        {
          link: {
            display_name: 'I\'m very long',
            url: 'x' * 2500
          }
        }
      end

      it do
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
