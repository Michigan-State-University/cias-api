# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/problems/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }

  let(:allow_guests) { false }
  let(:problem_user) { admin }
  let(:interventions) { create_list(:intervention, 2) }
  let!(:problem) { create(:problem, name: 'Some problem', user: problem_user, interventions: interventions, allow_guests: allow_guests) }

  context 'when endpoint is available' do
    before { get v1_problem_path(problem.id) }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    let(:headers) { user.create_new_auth_token }

    context 'is without credentials' do
      before do
        get v1_problem_path(problem.id)
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get v1_problem_path(problem.id), headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get v1_problem_path(problem.id), headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when user' do
    before { get v1_problem_path(problem.id), headers: user.create_new_auth_token }

    context 'has role admin' do
      it 'contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'Some problem',
          'allow_guests' => false
        )
      end

      it 'contains proper interventions collection' do
        expect(json_response['data']['attributes']['interventions'].pluck('id')).to match_array(interventions.pluck(:id))
      end
    end

    context 'has role participant' do
      let(:user) { participant }

      it 'contains empty data' do
        expect(json_response['data']).not_to be_present
      end
    end

    context 'has role researcher' do
      let(:user) { researcher }

      context 'problem does not belong to him' do
        it 'contains empty data' do
          expect(json_response['data']).not_to be_present
        end
      end

      context 'problem belongs to him' do
        let(:problem_user) { researcher }

        it 'contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'name' => 'Some problem',
            'allow_guests' => false
          )
        end

        it 'contains proper interventions collection' do
          expect(json_response['data']['attributes']['interventions'].pluck('id')).to match_array(interventions.pluck(:id))
        end
      end
    end

    context 'has role guest' do
      let(:user) { guest }

      context 'problem is not allowed for guests' do
        it 'contains empty data' do
          expect(json_response['data']).not_to be_present
        end
      end

      context 'problem is allowed for guests' do
        let(:allow_guests) { true }

        it 'contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'name' => 'Some problem',
            'allow_guests' => true
          )
        end

        it 'contains proper interventions collection' do
          expect(json_response['data']['attributes']['interventions'].pluck('id')).to match_array(interventions.pluck(:id))
        end
      end
    end
  end
end
