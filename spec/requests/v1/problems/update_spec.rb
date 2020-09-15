# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/problems', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:params) do
    {
      problem: {
        name: 'New Problem',
        status_event: 'broadcast'
      }
    }
  end

  let(:problem_user) { admin }
  let!(:problem) { create(:problem, name: 'Old Problem', user: problem_user, status: 'draft') }
  let(:problem_id) { problem.id }

  context 'when auth' do
    context 'is invalid' do
      before { patch v1_problem_path(problem_id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { patch v1_problem_path(problem_id), params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'is response header Content-Type eq JSON' do
    before { patch v1_problem_path(problem_id), params: params, headers: headers }

    it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
  end

  context 'when user has role admin' do
    before { patch v1_problem_path(problem_id), params: params, headers: headers }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:ok) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Problem',
          'status' => 'published',
          'shared_to' => 'anyone'
        )
      end

      it 'updates a problem object' do
        expect(problem.reload.attributes).to include(
          'name' => 'New Problem',
          'status' => 'published',
          'shared_to' => 'anyone'
        )
      end
    end

    context 'when params are INVALID' do
      let(:params) do
        {
          problem: {
            name: ''
          }
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq "Validation failed: Name can't be blank"
      end

      it 'does not update a problem object' do
        expect(problem.reload.attributes).to include(
          'name' => 'Old Problem',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end
    end
  end

  context 'when user has role researcher' do
    let(:user) { researcher }

    before { patch v1_problem_path(problem_id), params: params, headers: headers }

    context 'problem does not belong to him' do
      it { expect(response).to have_http_status(:not_found) }
    end

    context 'problem belongs to him' do
      let(:problem_user) { researcher }

      context 'when params are VALID' do
        it { expect(response).to have_http_status(:ok) }

        it 'response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'name' => 'New Problem',
            'status' => 'published',
            'shared_to' => 'anyone'
          )
        end

        it 'updates a problem object' do
          expect(problem.reload.attributes).to include(
            'name' => 'New Problem',
            'status' => 'published',
            'shared_to' => 'anyone'
          )
        end
      end

      context 'when params are INVALID' do
        let(:params) do
          {
            problem: {
              name: ''
            }
          }
        end

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq "Validation failed: Name can't be blank"
        end

        it 'does not update a problem object' do
          expect(problem.reload.attributes).to include(
            'name' => 'Old Problem',
            'status' => 'draft',
            'shared_to' => 'anyone'
          )
        end
      end
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    before { patch v1_problem_path(problem_id), params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context 'when user has role guest' do
    let(:user) { guest }

    before { patch v1_problem_path(problem_id), params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end
end
