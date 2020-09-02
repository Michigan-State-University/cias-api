# frozen_string_literal: true

require 'rails_helper'

describe 'GET /v1/problems/:problem_id/users', type: :request do
  let(:participants) { create_list(:user, 2, :confirmed, :participant) }

  let(:problem) { create(:problem, user_id: current_user.id, users: participants) }
  let(:problem_id) { problem.id }

  before { get v1_problem_users_path(problem_id: problem_id), headers: current_user.create_new_auth_token }

  context 'when current_user is admin' do
    let(:current_user) { create(:user, :confirmed, :admin) }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains records related to participants' do
        expect(json_response['data'].size).to eq 2
      end

      it 'JSON response contains proper associations with users' do
        expect(json_response['data'].pluck('attributes')).to match_array(
          [
            {
              'user' => include(
                'id' => participants[0].id
              ),
              'problem' => include(
                'id' => problem_id
              )
            },
            {
              'user' => include(
                'id' => participants[1].id
              ),
              'problem' => include(
                'id' => problem_id
              )
            }
          ]
        )
      end
    end

    context 'when problem does not exist' do
      let(:problem_id) { problem.id.reverse }

      it { expect(response).to have_http_status(:ok) }

      it 'returns empty collection' do
        expect(json_response['data'].size).to eq 0
      end
    end
  end

  context 'when current_user is researcher' do
    let(:current_user) { create(:user, :confirmed, :researcher) }

    context 'problem belongs to him' do
      context 'when params are VALID' do
        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains records related to participants' do
          expect(json_response['data'].size).to eq 2
        end

        it 'JSON response contains proper associations with users' do
          expect(json_response['data'].pluck('attributes')).to match_array(
            [
              {
                'user' => include(
                  'id' => participants[0].id
                ),
                'problem' => include(
                  'id' => problem_id
                )
              },
              {
                'user' => include(
                  'id' => participants[1].id
                ),
                'problem' => include(
                  'id' => problem_id
                )
              }
            ]
          )
        end
      end

      context 'when problem does not exist' do
        let(:problem_id) { problem.id.reverse }

        it { expect(response).to have_http_status(:ok) }

        it 'returns empty collection' do
          expect(json_response['data'].size).to eq 0
        end
      end
    end

    context 'problem does not belong to him' do
      let(:other_problem) { create(:problem, user_id: create(:user).id) }
      let(:problem_id) { other_problem.id }

      it { expect(response).to have_http_status(:ok) }

      it 'returns empty collection' do
        expect(json_response['data'].size).to eq 0
      end
    end
  end

  context 'when current_user is participant' do
    let(:current_user) { create(:user, :participant) }

    it { expect(response).to have_http_status(:ok) }

    it 'returns empty collection' do
      expect(json_response['data'].size).to eq 0
    end
  end

  context 'when current_user is guest' do
    let(:current_user) { create(:user, :confirmed, :guest) }

    it { expect(response).to have_http_status(:ok) }

    it 'returns empty collection' do
      expect(json_response['data'].size).to eq 0
    end
  end
end
