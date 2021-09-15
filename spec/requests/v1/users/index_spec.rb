# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users', type: :request do
  let(:user) { create(:user, :confirmed, roles: %w[participant admin guest], first_name: 'John', last_name: 'Twain', email: 'john.twain@test.com', created_at: 5.days.ago) }
  let(:researcher) { create(:user, :confirmed, :researcher, first_name: 'Mike', last_name: 'Wazowski', email: 'mike.Wazowski@test.com', created_at: 4.days.ago) }
  let(:participant) { create(:user, :confirmed, :participant, first_name: 'John', last_name: 'Lenon', email: 'john.lenon@test.com', created_at: 4.days.ago) }
  let(:participant_1) { create(:user, :confirmed, :participant, first_name: 'John', last_name: 'Doe', email: 'john.doe@test.com', created_at: 3.days.ago) }
  let(:participant_2) { create(:user, :confirmed, :participant, first_name: 'Jane', last_name: 'Doe', email: 'jane.doe@test.com', created_at: 2.days.ago) }
  let(:participant_3) { create(:user, :confirmed, :participant, first_name: 'Mark', last_name: 'Smith', email: 'mark.smith@test.com', created_at: 1.day.ago) }
  let(:users_deactivated) { create_list(:user, 2, active: false, roles: %w[participant]) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_users_path, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_users_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when current_user is admin' do
    let(:current_user) { user }

    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }

      let!(:users) { [participant_3, participant_2, participant_1, researcher, current_user] }

      before do
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'with pagination params' do
      let!(:params) { { page: 1, per_page: 2 } }
      let!(:users) { [participant_3, participant_2] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant_1, user] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'with team_id filter params' do
      let!(:team1) { create(:team) }
      let!(:team2) { create(:team) }
      let(:params) { { team_id: team1.id } }

      before do
        create(:user, :researcher, team_id: team1.id)
        create(:user, :researcher, team_id: team2.id)
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to match_array(team1.users.pluck(:id))
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq team1.users.size
      end
    end

    context 'with filters deactivated users' do
      let(:params) { { active: false } }
      let(:users) { [participant_1, participant_2, participant_3] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq 0
      end
    end

    context 'with filters active users' do
      let!(:params) { { active: false } }
      let!(:users) { users_deactivated }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end
  end

  context 'when current_user is researcher' do
    let(:current_user) { researcher }
    let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: participant_1, session: session)) }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }
      let!(:users) { [participant_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'with pagination params' do
      let!(:params) { { page: 1, per_page: 2 } }
      let!(:users) { [participant_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'when researcher does not have any session but participant answered other user question' do
      let!(:params) { {} }
      let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: participant_1, session: session)) }

      before { request }

      it 'returns empty list of users' do
        expect(json_response['users'].size).to eq 0
      end
    end

    context 'when nobody answered on researcher questions' do
      let!(:params) { {} }
      let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let!(:answer) {}

      before { request }

      it 'returns empty list of users' do
        expect(json_response['users'].size).to eq 0
      end
    end

    context 'when researcher wants to see other researchers from team' do
      let!(:team) { create(:team) }
      let!(:researcher_1) { create(:user, :confirmed, :researcher, first_name: 'Oliver', last_name: 'Wood', email: 'oliver.Wood@test.com', created_at: 4.days.ago, team_id: team.id) }
      let!(:add_current_user_to_team) { researcher.team_id = team.id }
      let!(:params) { { roles: %w[researcher], team_id: team.id } }
      let!(:users) { [researcher_1, current_user] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end
  end

  context 'when current_user is e-intervention-admin' do
    let_it_be(:organization) { create(:organization, name: 'Awesome Organization') }
    let(:current_user) { create(:user, :confirmed, :e_intervention_admin, first_name: 'John', last_name: 'E-intervention admin', email: 'john.e_intervention_admin@test.com', created_at: 5.days.ago, organizable: organization) }
    let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: participant_1, session: session)) }
    let!(:answer2) { create(:answer_slider, question: question, user_session: create(:user_session, user: participant_2, session: session)) }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }
      let!(:users) { [participant_2, participant_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'with pagination params' do
      let!(:params) { { page: 1, per_page: 1 } }
      let!(:users) { [participant_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to include(participant_2.id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq 1
      end
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end

    context 'when researcher does not have any session but participant answered other user question' do
      let!(:params) { {} }
      let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: participant_1, session: session)) }

      before { request }

      it 'returns empty list of users' do
        expect(json_response['users'].size).to eq 0
      end
    end

    context 'when e-intervention admin wants to see other researchers from team' do
      let!(:team) { create(:team) }
      let!(:researcher_1) { create(:user, :confirmed, :researcher, first_name: 'Oliver', last_name: 'Wood', email: 'oliver.Wood@test.com', created_at: 4.days.ago, team_id: team.id) }
      let!(:add_current_user_to_team) { current_user.team_id = team.id }
      let!(:params) { { roles: %w[researcher], team_id: team.id } }
      let!(:users) { [researcher_1] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end

      context 'and want to see other e-intervention admins from organization' do
        let!(:e_intervention_admin) { create(:user, :e_intervention_admin, organizable: organization, team_id: team.id) }
        let!(:params) { { roles: %w[researcher e_intervention_admin], team_id: team.id } }
        let!(:users) { [e_intervention_admin, researcher_1, current_user] }

        it 'returns correct http status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns correct user ids' do
          expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
        end

        it 'returns correct users list size' do
          expect(json_response['users'].size).to eq users.size
        end
      end
    end

    context 'when e-intervention admin wants to see other e-intervention from organization' do
      let!(:e_intervention_admin) { create(:user, :e_intervention_admin, organizable: organization) }
      let!(:params) { { roles: %w[e_intervention_admin] } }
      let!(:users) { [e_intervention_admin, current_user] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end
  end

  context 'when current_user is participant' do
    let(:current_user) { participant }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let(:params) { {} }
      let(:users) { [participant] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['users'].pluck('id')).to eq users.pluck(:id)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq users.size
      end
    end
  end

  context 'when current_user is team_admin' do
    let!(:team1) { create(:team) }
    let!(:current_user) { team1.team_admin }

    let!(:team_participant) { create(:user, :participant, :confirmed) }
    let!(:team_participant2) { create(:user, :participant, :confirmed) }
    let!(:other_team_participant) { create(:user, :participant, first_name: 'John', team_id: team1.id) }

    let!(:team_researcher) { create(:user, :researcher, :confirmed, team_id: team1.id) }
    let!(:team_intervention_admin) { create(:user, :e_intervention_admin, :confirmed, team_id: team1.id) }

    let!(:answer1) do
      session = create(:session, intervention: create(:intervention, user: team_researcher))
      question_group = create(:question_group, title: 'Test Question Group', session: session, position: 1)
      question = create(:question_slider, question_group: question_group)
      create(:answer_slider, question: question, user_session: create(:user_session, user: team_participant, session: session))
    end

    let!(:answer2) do
      session = create(:session, intervention: create(:intervention, user: team_intervention_admin))
      question_group = create(:question_group, title: 'Test Question Group', session: session, position: 1)
      question = create(:question_slider, question_group: question_group)
      create(:answer_slider, question: question, user_session: create(:user_session, user: team_participant2, session: session))
    end

    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }
    let(:expected_users_ids) { [*team1.users.pluck(:id), current_user.id, team_participant.id, team_participant2.id] }

    let!(:team2) { create(:team) }
    let!(:other_researchers) do
      create(:user, :researcher, team_id: team1.id)
      create(:user, :researcher, team_id: team2.id)
    end

    context 'without params' do
      let(:params) { {} }

      before do
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns users only from his team' do
        expect(json_response['users'].pluck('id')).to match_array(expected_users_ids)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq expected_users_ids.size
      end
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[participant] } }
      let!(:expected_users_ids) { [other_team_participant] }

      before do
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns users only from his team' do
        expect(json_response['users'].pluck('id')).to match_array(expected_users_ids.pluck(:id))
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq expected_users_ids.size
      end
    end

    context 'with team_id params' do
      let!(:params) { { team_id: team1.id } }
      let!(:expected_users_ids) { [*team1.users, team_participant, team_participant2] }

      before do
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns users only from his team' do
        expect(json_response['users'].pluck('id')).to match_array(expected_users_ids.pluck(:id))
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq expected_users_ids.size
      end
    end
  end
end
