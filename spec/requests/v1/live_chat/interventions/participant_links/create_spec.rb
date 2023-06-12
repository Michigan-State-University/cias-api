# frozen_string_literal: true

RSpec.describe 'POST /v1/live_chat/intervention/:id/navigator_setups/links', type: :request do
  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    post v1_live_chat_intervention_navigator_setups_links_path(id: intervention.id), params: params, headers: headers
  end

  before { request }

  context 'correctly creates new participant link' do
    let(:params) do
      {
        link: {
          url: 'https://google.com',
          display_name: 'University of Google'
        }
      }
    end

    it 'returns correct status code (Created)' do
      expect(response).to have_http_status(:created)
    end

    it 'correctly creates a new link' do
      setup = intervention.navigator_setup.reload
      expect(setup.participant_links.count).to eq 1
      expect(setup.participant_links[0].display_name).to eq 'University of Google'
      expect(setup.participant_links[0].url).to eq 'https://google.com'
    end
  end

  context 'correctly creates new navigator link' do
    let(:params) do
      {
        link: {
          url: 'https://google.com',
          display_name: 'University of Google',
          link_for: 'navigators'
        }
      }
    end

    it 'returns correct status code (Created)' do
      expect(response).to have_http_status(:created)
    end

    it 'correctly creates a new link' do
      setup = intervention.navigator_setup.reload
      expect(setup.navigator_links.count).to eq 1
      expect(setup.navigator_links[0].display_name).to eq 'University of Google'
      expect(setup.navigator_links[0].url).to eq 'https://google.com'
    end
  end

  context 'only current editor can create invitations in the intervention with collaborators' do
    let(:params) do
      {
        link: {
          url: 'https://google.com',
          display_name: 'University of Google'
        }
      }
    end
    let(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: create(:user, :researcher, :confirmed)) }

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
