# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:params) do
    {
      intervention: {
        name: 'New Intervention'
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { post v1_interventions_path }

      it { expect(response).to have_http_status(:unauthorized) }
    end

    context 'is valid' do
      before { post v1_interventions_path, params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'is response header Content-Type eq JSON' do
    before { post v1_interventions_path, params: params, headers: headers }

    it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
  end

  context 'when user has role admin' do
    before { post v1_interventions_path, params: params, headers: headers }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Intervention',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end

      it 'creates a intervention object' do
        expect(Intervention.last.attributes).to include(
          'name' => 'New Intervention',
          'user_id' => admin.id,
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end
    end

    context 'when params are INVALID' do
      let(:params) do
        {
          intervention: {
            name: ''
          }
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq "Validation failed: Name can't be blank"
      end

      it 'does not create a intervention object' do
        expect(Intervention.all.size).to eq 0
      end
    end
  end

  context 'when user has role researcher' do
    let(:user) { researcher }

    before { post v1_interventions_path, params: params, headers: headers }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'name' => 'New Intervention',
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end

      it 'creates a intervention object' do
        expect(Intervention.last.attributes).to include(
          'name' => 'New Intervention',
          'user_id' => researcher.id,
          'status' => 'draft',
          'shared_to' => 'anyone'
        )
      end
    end

    context 'when params are INVALID' do
      let(:params) do
        {
          intervention: {
            name: ''
          }
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq "Validation failed: Name can't be blank"
      end

      it 'does not create a intervention object' do
        expect(Intervention.all.size).to eq 0
      end
    end
  end

  context 'when user has role participant' do
    let(:user) { participant }

    before { post v1_interventions_path, params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end

  context 'when user has role guest' do
    let(:user) { guest }

    before { post v1_interventions_path, params: params, headers: headers }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end
end
