# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/auth/password', type: :request do
  let(:current_user) { create(:user, :admin, password: 'SomePassword1!') }
  let(:current_password) { 'SomePassword1!' }
  let(:password) { 'ComplPass12!' }
  let(:password_confirmation) { password }
  let(:params) do
    {
      current_password: current_password,
      password: password,
      password_confirmation: password_confirmation
    }
  end

  before { patch '/v1/auth', headers: current_user.create_new_auth_token, params: params }

  context 'when params are valid' do
    it { expect(response).to have_http_status(:ok) }

    it 'JSON response contains proper attributes' do
      expect(json_response['data']['attributes']).to include(
        'email' => current_user.email
      )
    end

    it 'changes password' do
      expect(current_user.reload.valid_password?('ComplPass12!')).to be true
    end
  end

  context 'when params are INVALID' do
    context 'current_password is INVALID' do
      let(:current_password) { 'InvalidCurrentPassword' }

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'does not change password' do
        expect(current_user.reload.valid_password?('NewPassword1!')).to be false
      end

      it 'contains the proper error message' do
        expect(json_response['message']).to eq 'Current password is invalid'
      end
    end

    context 'password and password_confirmation are not the same' do
      let(:password_confirmation) { 'OtherPassword1!' }

      it { expect(response).to have_http_status(:unprocessable_entity) }

      it 'does not change password' do
        expect(current_user.reload.valid_password?('NewPassword1!')).to be false
      end

      it 'contains the proper error message' do
        expect(json_response['message']).to eq "Password confirmation doesn't match Password"
      end
    end
  end
end
