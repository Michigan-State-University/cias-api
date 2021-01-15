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

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_users_path, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
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
        expect(json_response['users'].size).to eq 5
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
        expect(json_response['users'].size).to eq 2
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
        expect(json_response['users'].size).to eq 2
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
        expect(json_response['users'].size).to eq 2
      end
    end
  end

  context 'when current_user is researcher' do
    let(:current_user) { researcher }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'without params' do
      let!(:params) { {} }
      let!(:users) { [participant_3, participant_2, participant_1, researcher] }

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
        expect(json_response['users'].size).to eq 4
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
        expect(json_response['users'].size).to eq 2
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
        expect(json_response['users'].size).to eq 1
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
        expect(json_response['users'].size).to eq 1
      end
    end
  end
end
