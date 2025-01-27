# frozen_string_literal: true

RSpec.describe 'POST /v1/live_chat/intervention/:id/navigators', type: :request do
  let(:team) { create(:team) }
  let(:user) { create(:user, :researcher, :confirmed, team: team) }
  let(:intervention) { create(:intervention, user: user) }
  let(:navigator) { create(:user, :navigator, team: team) }
  let(:headers) { user.create_new_auth_token }

  let(:params) { { navigator_id: navigator.id } }

  let(:request) do
    post v1_live_chat_intervention_navigators_path(id: intervention.id), headers: headers, params: params
  end

  before { request }

  context 'when user has access' do
    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data' do
      expect(json_response['data']).to include(
        'id' => navigator.id,
        'type' => 'navigator',
        'attributes' => include(
          'first_name' => navigator.first_name,
          'last_name' => navigator.last_name,
          'email' => navigator.email,
          'avatar_url' => nil
        )
      )
    end

    context 'when navigator doesn\'t belong to team' do
      let(:navigator) { create(:user, :navigator) }

      it 'returns correct status code (NOT FOUND)' do
        expect(response).to have_http_status(:not_found)
      end

      it 'return correct message' do
        expect(json_response['message']).to include("Couldn't find User with 'id'=")
      end
    end

    context 'when user is team admin' do
      let(:user) { create(:user, :team_admin, :confirmed) }
      let(:navigator) { create(:user, :navigator, team: user.admins_teams.first) }

      it 'returns correct status code (OK)' do
        expect(response).to have_http_status(:ok)
      end

      it 'return correct data' do
        expect(json_response['data']).to include(
          'id' => navigator.id,
          'type' => 'navigator',
          'attributes' => include(
            'first_name' => navigator.first_name,
            'last_name' => navigator.last_name,
            'email' => navigator.email,
            'avatar_url' => nil
          )
        )
      end
    end

    context 'but isn\'t the current editor' do
      let(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: create(:user, :researcher, :confirmed)) }

      it { expect(response).to have_http_status(:forbidden) }
    end
  end

  context 'other researcher' do
    let(:other_researcher) { create(:user, :researcher, :confirmed) }
    let(:headers) { other_researcher.create_new_auth_token }

    it 'return correct status code and msg' do
      expect(response).to have_http_status(:not_found)
      expect(json_response['message']).to include("Couldn't find Intervention with 'id'=")
    end
  end
end
