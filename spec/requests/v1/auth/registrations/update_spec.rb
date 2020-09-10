# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/auth', type: :request do
  let(:current_user) { create(:user, :admin, password: 'SomePassword1!', email: 'old-email@test.com') }
  let(:params) do
    {
      email: 'new-email@test.com',
      current_password: 'SomePassword1!'
    }
  end

  before { patch '/v1/auth', headers: current_user.create_new_auth_token, params: params }

  context 'when params are valid' do
    it { expect(response).to have_http_status(:ok) }

    it 'JSON response contains proper attributes' do
      expect(json_response['data']['attributes']).to include(
        'email' => 'new-email@test.com'
      )
    end

    it 'changes attributes' do
      expect(current_user.reload.attributes).to include(
        'email' => 'new-email@test.com'
      )
    end
  end

  context 'when params are INVALID' do
    context 'current_password is INVALID' do
      let(:params) do
        {
          email: 'new-email@test.com',
          current_password: 'NotCurrentPassword'
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'does not change attributes' do
        expect(current_user.reload.attributes).to include(
          'email' => 'old-email@test.com'
        )
      end

      it 'contains the proper error message' do
        expect(json_response['message']).to eq 'Current password is invalid'
      end
    end

    context 'email is INVALID' do
      let(:params) do
        {
          email: 'invalid-email',
          current_password: 'SomePassword1!'
        }
      end

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'does not change attributes' do
        expect(current_user.reload.attributes).to include(
          'email' => 'old-email@test.com'
        )
      end

      it 'contains the proper error message' do
        expect(json_response['message']).to eq 'Email is not an email'
      end
    end
  end
end
