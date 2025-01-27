# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/intervention/:id/navigator_tab', type: :request do
  let(:team_admin) { create(:user, :team_admin, :confirmed) }
  let(:team) { create(:team, team_admin: team_admin) }
  let(:user) { create(:user, :researcher, :confirmed, team: team) }
  let(:intervention) { create(:intervention, :with_navigator_setup, :with_navigators, user: user) }
  let(:headers) { user.create_new_auth_token }
  let(:request) do
    get v1_live_chat_intervention_navigator_tab_path(id: intervention.id), headers: headers
  end

  context 'correctly fetches navigator tab data' do
    let!(:navigator_invitation) { create(:navigator_invitation, intervention: intervention) }
    let!(:navigator) { create(:user, :navigator, :confirmed, team: team) }

    before { request }

    it 'return correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return correct send_invitations' do
      keys = %w[id email type]
      expect(json_response['data']['attributes']['sent_invitations'].first.keys).to match_array(keys)
      expect(json_response['data']['attributes']['sent_invitations'].size).to be(1)
    end

    it 'response has correct navigators in the team' do
      keys = %w[id first_name last_name email avatar_url]
      expect(json_response['data']['attributes']['navigators_in_team'].first.keys).to match_array(keys)
      expect(json_response['data']['attributes']['navigators_in_team'].size).to be(1)
    end

    it 'response has correct invitations' do
      keys = %w[id first_name last_name email avatar_url]
      expect(json_response['data']['attributes']['navigators'].first.keys).to match_array(keys)
      expect(json_response['data']['attributes']['navigators'].size).to be(1)
    end

    context 'when navigator doesn\'t belong to team' do
      let!(:researcher_without_team) { create(:user, :researcher, :confirmed) }
      let(:intervention2) { create(:intervention, :with_navigator_setup, :with_navigators, user: researcher_without_team) }
      let(:headers) { researcher_without_team.create_new_auth_token }

      let(:request) do
        get v1_live_chat_intervention_navigator_tab_path(id: intervention2.id), headers: headers
      end

      it 'return empty array in navigator in the team section' do
        expect(json_response['data']['attributes']['navigators_in_team'].size).to be(0)
      end
    end
  end

  context 'when user has no permission to intervention' do
    let(:other_researcher) { create(:user, :researcher, :confirmed) }
    let(:headers) { other_researcher.create_new_auth_token }

    it 'return correct status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
