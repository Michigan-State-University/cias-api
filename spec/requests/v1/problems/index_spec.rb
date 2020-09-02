# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/problems', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }

  let!(:admin_problems) { create_list(:problem, 3, user: admin, shared_to: :registered) }
  let!(:researcher_problems) { create_list(:problem, 3, user: researcher, shared_to: :invited) }
  let!(:problems_for_guests) { create_list(:problem, 2) }

  context 'when endpoint is available' do
    before { get v1_problems_path }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    let(:headers) { user.create_new_auth_token }

    context 'is without credentials' do
      let(:params) { {} }

      before { get v1_problems_path, params: params }

      context 'without params' do
        it { expect(response).to have_http_status(:unauthorized) }

        it 'response is without user token' do
          expect(response.headers['access-token']).to be_nil
        end
      end

      context 'with allow_guests parameter' do
        let(:params) { { allow_guests: 'true' } }
        let(:problems_scope) { problems_for_guests }

        it { expect(response).to have_http_status(:ok) }

        it 'returns proper problems' do
          expect(json_response['data'].pluck('id')).to match_array problems_scope.map(&:id)
        end
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get v1_problems_path, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get v1_problems_path, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when user' do
    before { get v1_problems_path, headers: user.create_new_auth_token }

    context 'has role admin' do
      let(:problems_scope) { admin_problems + researcher_problems + problems_for_guests }

      it 'returns proper problems' do
        expect(json_response['data'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end

    context 'has role participant' do
      let(:user) { participant }

      it 'returns proper error message' do
        expect(json_response['data']).to eq []
      end
    end

    context 'has role researcher' do
      let(:user) { researcher }
      let(:problems_scope) { researcher_problems }

      it 'returns proper problems' do
        expect(json_response['data'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end

    context 'has role guest' do
      let(:user) { guest }
      let(:problems_scope) { problems_for_guests }

      it 'returns proper problems' do
        expect(json_response['data'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end
  end
end
