# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/problems', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }

  let!(:admin_problems) { create_list(:problem, 3, :published, user: admin, shared_to: :registered) }
  let!(:researcher_problems) { create_list(:problem, 3, :published, user: researcher, shared_to: :invited) }
  let!(:problems_for_guests) { create_list(:problem, 2, :published) }

  context 'when user' do
    before { get v1_problems_path, headers: user.create_new_auth_token }

    context 'has role admin' do
      let(:problems_scope) { admin_problems + researcher_problems + problems_for_guests }

      it 'returns proper problems' do
        expect(json_response['problems'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end

    context 'has role participant' do
      let(:user) { participant }
      let(:problems_scope) { admin_problems + problems_for_guests }

      it 'returns proper error message' do
        expect(json_response['problems'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end

    context 'has role researcher' do
      let(:user) { researcher }
      let(:problems_scope) { researcher_problems }

      it 'returns proper problems' do
        expect(json_response['problems'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end

    context 'has role guest' do
      let(:user) { guest }
      let(:problems_scope) { problems_for_guests }

      it 'returns proper problems' do
        expect(json_response['problems'].pluck('id')).to match_array problems_scope.map(&:id)
      end
    end
  end
end
