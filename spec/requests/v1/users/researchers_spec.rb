# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users/researchers', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:team) { create(:team) }
  let(:team_admin) { team.team_admin }
  let!(:researcher) { create(:user, :confirmed, :researcher, team_id: team.id) }
  let!(:other_researcher) { create(:user, :confirmed, :researcher, team_id: team.id) }
  let(:participant) { create(:user, :confirmed, :participant, team_id: team.id) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_researchers_path, headers: headers, params: {} }

  let(:researchers) { [other_researcher, researcher] }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_researchers_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when current_user is admin' do
    context 'without pagination params' do
      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['data'].pluck('id')).to match_array(researchers.pluck(:id))
      end

      it 'returns correct users list size' do
        expect(json_response['data'].size).to eq researchers.size
      end
    end

    context 'with pagination params' do
      let!(:params) { { page: 1, per_page: 1 } }

      before { request }

      it 'returns correct http status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns correct user ids' do
        expect(json_response['data'].pluck('id')).to match_array(researchers.pluck(:id))
      end

      it 'returns correct users list size' do
        expect(json_response['data'].size).to eq researchers.size
      end
    end
  end

  context 'when current_user is researcher' do
    let!(:user) { researcher }

    before { request }

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct user ids' do
      expect(json_response['data'].pluck('id')).to match_array(researchers.pluck(:id))
    end

    it 'returns correct users list size' do
      expect(json_response['data'].size).to eq researchers.size
    end
  end

  context 'when current_user is participant' do
    let!(:user) { participant }

    before { request }

    it 'returns correct http status' do
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when current_user is team_admin' do
    let!(:user) { team_admin }
    let(:team2) { create(:team) }

    before do
      create(:user, :researcher, team_id: team2.id)
      create(:user, :researcher, team_id: team2.id)
      create(:user, :participant, team_id: team2.id)
      create(:user, :participant, team_id: team.id)
      request
    end

    it 'returns correct http status' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns users only from his team' do
      expect(json_response['data'].pluck('id')).to match_array(researchers.pluck(:id))
    end

    it 'returns correct users list size' do
      expect(json_response['data'].size).to eq researchers.size
    end
  end
end
