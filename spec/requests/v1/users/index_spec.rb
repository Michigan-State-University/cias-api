# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users', type: :request do
  let(:user) do
    create(:user, :confirmed, roles: %w[participant admin guest], first_name: 'John', last_name: 'Twain', email: 'john.twain@test.com', created_at: 5.days.ago)
  end
  let(:researcher) do
    create(:user, :confirmed, :researcher, first_name: 'Mike', last_name: 'Wazowski', email: 'mike.Wazowski@test.com', created_at: 4.days.ago)
  end
  let(:participant) { create(:user, :confirmed, :participant, first_name: 'John', last_name: 'Lenon', email: 'john.lenon@test.com', created_at: 4.days.ago) }
  let(:participant1) { create(:user, :confirmed, :participant, first_name: 'John', last_name: 'Doe', email: 'john.doe@test.com', created_at: 3.days.ago) }
  let(:participant2) { create(:user, :confirmed, :participant, first_name: 'Jane', last_name: 'Doe', email: 'jane.doe@test.com', created_at: 2.days.ago) }
  let(:participant3) { create(:user, :confirmed, :participant, first_name: 'Mark', last_name: 'Smith', email: 'mark.smith@test.com', created_at: 1.day.ago) }
  let(:users_deactivated) { create_list(:user, 2, active: false, roles: %w[participant]) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_users_path, headers: headers }

  shared_examples 'correct users response' do
    before do
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct user ids' do
      expect(json_response['data'].pluck('id')).to match_array users.pluck(:id)
    end

    it 'returns correct users list size' do
      expect(json_response['data'].size).to eq users.size
    end
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_users_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  # ADMIN
  context 'when current_user is admin' do
    let(:current_user) { user }

    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }

      let!(:users) { [participant3, participant2, participant1, researcher, current_user] }

      it_behaves_like 'correct users response'
    end

    context 'with pagination params' do
      let!(:params) { { page: 1, per_page: 2 } }
      let!(:users) { [participant3, participant2] }

      it_behaves_like 'correct users response'
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant1, user] }

      it_behaves_like 'correct users response'
    end

    context 'with team_id filter params' do
      let!(:team1) { create(:team) }
      let!(:team2) { create(:team) }
      let(:params) { { team_id: team1.id } }
      let(:users) { team1.users }

      before do
        create(:user, :researcher, team_id: team1.id)
        create(:user, :researcher, team_id: team2.id)
      end

      it_behaves_like 'correct users response'
    end

    context 'with filters deactivated users' do
      let(:params) { { active: false } }
      let(:users) { [participant1, participant2, participant3] }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct users list size' do
        expect(json_response['data'].size).to eq 0
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
        expect(json_response['data'].size).to eq users.size
      end
    end
  end

  # RESEARCHER
  context 'when current_user is researcher' do
    let(:current_user) { researcher }
    let(:intervention) { create(:intervention, user: current_user) }
    let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let(:user_intervention) { create(:user_intervention, user: participant1, intervention: intervention) }
    let(:user_session) { create(:user_session, user: participant1, session: session, user_intervention: user_intervention) }
    let!(:answer) { create(:answer_slider, question: question, user_session: user_session) }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }
      let!(:users) { [participant1] }

      it_behaves_like 'correct users response'
    end

    context 'with pagination params' do
      let!(:params) { { page: 1, per_page: 2 } }
      let!(:users) { [participant1] }

      it_behaves_like 'correct users response'
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant1] }

      it_behaves_like 'correct users response'
    end

    context 'when researcher does not have any session but participant answered other user question' do
      let!(:params) { {} }
      let(:intervention) { create(:intervention) }
      let!(:session) { create(:session, intervention: intervention) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let(:user_intervention) { create(:user_intervention, intervention: intervention, user: participant1) }
      let!(:answer) do
        create(:answer_slider, question: question,
                               user_session: create(:user_session, user: participant1, session: session, user_intervention: user_intervention))
      end

      before { request }

      it 'returns empty list of users' do
        expect(json_response['data'].size).to eq 0
      end
    end

    context 'when nobody answered on researcher questions' do
      let!(:params) { {} }
      let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let!(:answer) { nil }

      before { request }

      it 'returns empty list of users' do
        expect(json_response['data'].size).to eq 0
      end
    end

    context 'when researcher wants to see other researchers from team' do
      let!(:team) { create(:team) }
      let!(:researcher1) do
        create(:user, :confirmed, :researcher, first_name: 'Oliver', last_name: 'Wood', email: 'oliver.Wood@test.com',
                                               created_at: 4.days.ago, team_id: team.id)
      end
      let!(:add_current_user_to_team) { researcher.team_id = team.id }
      let!(:params) { { roles: %w[researcher], team_id: team.id } }
      let!(:users) { [researcher1, current_user] }

      it_behaves_like 'correct users response'
    end
  end

  context 'when current_user is team_admin' do
    let!(:team1) { create(:team) }
    let!(:current_user) { team1.team_admin }

    let!(:team_participant) { create(:user, :participant, :confirmed) }
    let!(:team_participant2) { create(:user, :participant, :confirmed) }
    let!(:team_admin_participant) { create(:user, :participant, :confirmed) }
    let!(:other_team_participant) { create(:user, :participant, first_name: 'John', team_id: team1.id) }

    let!(:team_researcher) { create(:user, :researcher, :confirmed, team_id: team1.id) }
    let!(:team_intervention_admin) { create(:user, :e_intervention_admin, :confirmed, team_id: team1.id) }

    let!(:answer1) do
      intervention = create(:intervention, user: team_researcher)
      user_intervention = create(:user_intervention, intervention: intervention, user: team_participant)
      session = create(:session, intervention: intervention)
      user_session = create(:user_session, session: session, user_intervention: user_intervention, user: team_participant)
      question_group = create(:question_group, title: 'Test Question Group', session: session, position: 1)
      question = create(:question_slider, question_group: question_group)
      create(:answer_slider, question: question, user_session: user_session)
    end

    let!(:answer2) do
      intervention = create(:intervention, user: team_intervention_admin)
      user_intervention = create(:user_intervention, intervention: intervention, user: team_participant2)
      session = create(:session, intervention: intervention)
      user_session = create(:user_session, session: session, user_intervention: user_intervention, user: team_participant2)
      question_group = create(:question_group, title: 'Test Question Group', session: session, position: 1)
      question = create(:question_slider, question_group: question_group)
      create(:answer_slider, question: question, user_session: user_session)
    end

    let!(:answer3) do
      intervention = create(:intervention, user: current_user)
      user_intervention = create(:user_intervention, intervention: intervention, user: team_admin_participant)
      session = create(:session, intervention: intervention)
      user_session = create(:user_session, session: session, user_intervention: user_intervention, user: team_admin_participant)
      question_group = create(:question_group, title: 'Test Question Group', session: session, position: 1)
      question = create(:question_slider, question_group: question_group)
      create(:answer_slider, question: question, user_session: user_session)
    end

    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }
    let(:users) { [*team1.users, current_user, team_participant, team_participant2, team_admin_participant] }

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

      it_behaves_like 'correct users response'
    end

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[participant] } }
      let!(:users) { [other_team_participant] }

      before do
        request
      end

      it_behaves_like 'correct users response'
    end

    context 'with team_id params' do
      let!(:params) { { team_id: team1.id } }
      let!(:users) { [*team1.users, team_participant, team_participant2, team_admin_participant] }

      before do
        request
      end

      it_behaves_like 'correct users response'
    end
  end

  %w[guest participant organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context "when current_user is #{role}" do
      let(:current_user) { create(:user, :confirmed, role) }
      let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

      context 'without params' do
        let(:params) { {} }
        let(:users) { [current_user] }

        before { request }

        it_behaves_like 'correct users response'
      end
    end
  end
end
