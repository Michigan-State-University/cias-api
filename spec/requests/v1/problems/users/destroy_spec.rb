# frozen_string_literal: true

require 'rails_helper'

describe 'DELETE /v1/problems/:problem_id/users/:id', type: :request do
  let(:participants) { create_list(:user, 2, :participant) }
  let(:problem) { create(:problem, users: participants, user_id: current_user.id) }

  let(:problem_id) { problem.id }
  let(:user_id) { participants.first.id }

  before { delete v1_problem_user_path(problem_id: problem_id, id: user_id), headers: current_user.create_new_auth_token }

  context 'when current_user is admin' do
    let(:current_user) { create(:user, :confirmed, :admin) }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:no_content) }

      it 'removes participant from problems' do
        expect(problem.reload.users.pluck(:id)).not_to include(user_id)
      end
    end

    context 'when problem does not exist' do
      let(:problem_id) { problem.id.reverse }

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'when user does not belong to problem' do
      let(:other_participant) { create(:user, :participant) }
      let(:user_id) { other_participant }

      it { expect(response).to have_http_status(:not_found) }
    end
  end

  context 'when current_user is researcher' do
    let(:current_user) { create(:user, :confirmed, :researcher) }

    context 'problem belongs to him' do
      context 'when params are VALID' do
        it { expect(response).to have_http_status(:no_content) }

        it 'removes participant from problems' do
          expect(problem.reload.users.pluck(:id)).not_to include(user_id)
        end
      end

      context 'when problem does not exist' do
        let(:problem_id) { problem.id.reverse }

        it { expect(response).to have_http_status(:not_found) }
      end

      context 'when user does not belong to problem' do
        let(:other_participant) { create(:user, :confirmed, :participant) }
        let(:user_id) { other_participant }

        it { expect(response).to have_http_status(:not_found) }
      end
    end

    context 'problem does not belong to him' do
      let(:other_problem) { create(:problem, user_id: create(:user).id) }
      let(:problem_id) { other_problem.id }

      it { expect(response).to have_http_status(:not_found) }

      it 'does not remove participant from problems' do
        expect(problem.reload.users.pluck(:id)).to include(user_id)
      end
    end
  end

  context 'when current_user is participant' do
    let(:current_user) { create(:user, :participant) }

    it { expect(response).to have_http_status(:not_found) }

    it 'does not remove participant from problems' do
      expect(problem.reload.users.pluck(:id)).to include(user_id)
    end
  end

  context 'when current_user is guest' do
    let(:current_user) { create(:user, :confirmed, :guest) }

    it { expect(response).to have_http_status(:not_found) }

    it 'does not remove participant from problems' do
      expect(problem.reload.users.pluck(:id)).to include(user_id)
    end
  end
end
