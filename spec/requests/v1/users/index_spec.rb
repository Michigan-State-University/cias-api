# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users', type: :request do
  let(:user) { create(:user, :confirmed, :admin, first_name: 'John', last_name: 'Twain', email: 'john.twain@test.com', created_at: 5.days.ago) }
  let(:researcher) { create(:user, :confirmed, :researcher, first_name: 'Mike', last_name: 'Wazowski', email: 'john.Wazowski@test.com', created_at: 4.days.ago) }
  let(:participant) { create(:user, :confirmed, :participant, first_name: 'John', last_name: 'Lenon', email: 'john.lenon@test.com', created_at: 4.days.ago) }
  let(:participant_1) { create(:user, :confirmed, :participant, first_name: 'John', last_name: 'Doe', email: 'john.doe@test.com', created_at: 3.days.ago) }
  let(:participant_2) { create(:user, :confirmed, :participant, first_name: 'Jane', last_name: 'Doe', email: 'jane.doe@test.com', created_at: 2.days.ago) }
  let(:participant_3) { create(:user, :confirmed, :participant, first_name: 'Mark', last_name: 'Smith', email: 'mark.smith@test.com', created_at: 1.day.ago) }
  let(:users_deactivated) { create_list(:user, 2, active: false, roles: %w[participant]) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_users_path }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { get v1_users_path, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when current_user is admin' do
    let(:current_user) { user }

    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }

      let!(:users) { [participant_3, participant_2, participant_1, researcher, user] }

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

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant_1, user] }

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

      before do
        request
      end

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

      before do
        request
      end

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
      let!(:users) { [participant_1] }

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

    context 'with filters params' do
      let!(:params) { { name: 'John', roles: %w[admin participant] } }
      let!(:users) { [participant_1] }

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

    context 'when researcher does not have any session but participant answered other user wuestion' do
      let!(:params) { {} }
      let!(:session) { create(:session, intervention: create(:intervention, user: user)) }
      let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
      let!(:question) { create(:question_slider, question_group: question_group) }
      let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: participant_1, session: session)) }

      before do
        request
      end

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

      before do
        request
      end

      it 'returns empty list of users' do
        expect(json_response['users'].size).to eq 0
      end
    end
  end

  context 'when current_user is participant' do
    let(:current_user) { participant }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let(:params) { {} }
      let(:users) { [participant] }

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
  end

  context 'when current_user is team_admin' do
    let!(:team1) { create(:team) }
    let(:current_user) { team1.team_admin }
    let(:team_participant) { create(:user, :participant, team_id: team1.id) }
    let(:other_team_participant) { create(:user, :participant, team_id: team1.id) }
    let!(:session) { create(:session, intervention: create(:intervention, user: current_user)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: team_participant, session: session)) }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }
    let(:expected_users_ids) { [*team1.users.pluck(:id), current_user.id] }

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
        expect(json_response['users'].pluck('id')).to match_array(expected_users_ids)
      end

      it 'returns correct users list size' do
        expect(json_response['users'].size).to eq expected_users_ids.size
      end
    end
  end
end
