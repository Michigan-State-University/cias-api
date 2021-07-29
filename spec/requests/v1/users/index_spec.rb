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
      expect(json_response['data'].pluck('id')).to eq users.pluck(:id)
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

  context 'when current_user is researcher' do
    let(:current_user) { researcher }
    let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let!(:answer) do
      create(:answer_slider, question: question,
                             user_session: create(:user_session, user: participant1, session: session))
    end
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
      let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let!(:answer) do
        create(:answer_slider, question: question,
                               user_session: create(:user_session, user: participant1, session: session))
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

  context 'when current_user is participant' do
    let(:current_user) { participant }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let(:params) { {} }
      let(:users) { [participant] }

      it_behaves_like 'correct users response'
    end
  end

  context 'when current_user is team_admin' do
    let!(:team1) { create(:team) }
    let(:current_user) { team1.team_admin }
    let(:team_participant) { create(:user, :participant, :confirmed) }
    let(:other_team_participant) { create(:user, :participant, :confirmed, team_id: team1.id) }
    let(:team_researcher) { create(:user, :researcher, :confirmed, team_id: team1.id) }
    let!(:session) { create(:session, intervention: create(:intervention, user: team_researcher)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let!(:answer) do
      create(:answer_slider, question: question,
                             user_session: create(:user_session, user: team_participant, session: session))
    end
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }
    let(:expected_users_ids) { [*team1.users.pluck(:id), current_user.id, team_participant.id] }

    context 'without params' do
      let!(:team2) { create(:team) }
      let(:params) { {} }

      before do
        create(:user, :researcher, team_id: team1.id)
        create(:user, :researcher, team_id: team2.id)
        request
      end

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns users only from his team' do
        expect(json_response['data'].pluck('id')).to match_array(expected_users_ids)
      end

      it 'returns correct users list size' do
        expect(json_response['data'].size).to eq expected_users_ids.size
      end
    end
  end
end
