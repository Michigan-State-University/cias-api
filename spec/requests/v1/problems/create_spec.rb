# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/problems', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:params) do
    {
      problem: {
        name: 'New Problem'
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { post v1_problems_path }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_problems_path, params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'is response header Content-Type eq JSON' do
    before { post v1_problems_path, params: params, headers: headers }

    it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
  end

  context 'when user has role admin' do
    before { post v1_problems_path, params: params, headers: headers }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Problem',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end

      it 'creates a problem object' do
        expect(Problem.last.attributes).to include(
          'name' => 'New Problem',
          'user_id' => admin.id,
          'status' => 'draft',
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

      it 'does not create a problem object' do
        expect(Problem.all.size).to eq 0
      end
    end
  end

  context 'when user has role researcher' do
    let(:user) { researcher }

    before { post v1_problems_path, params: params, headers: headers }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Problem',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end

      it 'creates a problem object' do
        expect(Problem.last.attributes).to include(
          'name' => 'New Problem',
          'user_id' => researcher.id,
          'status' => 'draft',
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

      it 'does not create a problem object' do
        expect(Problem.all.size).to eq 0
      end
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    before { post v1_problems_path, params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end

  context 'when user has role guest' do
    let(:user) { guest }

    before { post v1_problems_path, params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end
end
