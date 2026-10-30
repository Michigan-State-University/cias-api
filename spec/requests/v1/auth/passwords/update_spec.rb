# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PUT/PATCH /v1/auth/password', type: :request do
  let(:current_user) { create(:user, :confirmed, :researcher, password: 'SomePassword1!') }
  let(:new_password) { 'ComplPass12!' }
  let(:headers) { current_user.create_new_auth_token }

  context 'when signed-in user changes password' do
    let(:params) do
      {
        current_password: 'SomePassword1!',
        password: new_password,
        password_confirmation: new_password
      }
    end
    let(:request) { patch '/v1/auth/password', headers: headers, params: params }

    context 'when params are valid' do
      before { request }

      it { expect(response).to have_http_status(:ok) }

      it 'returns the user' do
        expect(json_response['data']['attributes']).to include('email' => current_user.email)
      end

      it 'changes password' do
        expect(current_user.reload.valid_password?(new_password)).to be true
      end
    end

    context 'when current_password is invalid' do
      before do
        params[:current_password] = 'InvalidCurrentPassword'
        request
      end

      it { expect(response).to have_http_status(:unprocessable_content) }

      it 'returns the error message' do
        expect(json_response['message']).to eq 'Current password is invalid'
      end

      it 'does not change password' do
        expect(current_user.reload.valid_password?('SomePassword1!')).to be true
      end
    end

    context 'when password confirmation does not match' do
      before do
        params[:password_confirmation] = 'OtherPassword1!'
        request
      end

      it { expect(response).to have_http_status(:unprocessable_content) }

      it 'returns the error message' do
        expect(json_response['message']).to eq "Password confirmation doesn't match Password"
      end

      it 'does not change password' do
        expect(current_user.reload.valid_password?('SomePassword1!')).to be true
      end
    end

    context 'when password params are missing' do
      before do
        params.except!(:password, :password_confirmation)
        request
      end

      it { expect(response).to have_http_status(:unprocessable_content) }

      it 'does not change password' do
        expect(current_user.reload.valid_password?('SomePassword1!')).to be true
      end
    end

    context 'when user is not signed in' do
      let(:headers) { {} }

      before { request }

      it { expect(response).to have_http_status(:unauthorized) }
    end
  end

  context 'when user sets a new password after following the reset link' do
    let(:params) { { password: new_password, password_confirmation: new_password } }
    let(:request) { put '/v1/auth/password', headers: headers, params: params }

    context 'when password change is allowed by the reset link' do
      before do
        current_user.update!(allow_password_change: true)
        request
      end

      it { expect(response).to have_http_status(:ok) }

      it 'changes password without current_password' do
        expect(current_user.reload.valid_password?(new_password)).to be true
      end

      it 'disallows another change without current_password' do
        expect(current_user.reload.allow_password_change).to be false
      end
    end

    context 'when password change is not allowed' do
      before { request }

      it { expect(response).to have_http_status(:unprocessable_content) }

      it 'does not change password' do
        expect(current_user.reload.valid_password?('SomePassword1!')).to be true
      end
    end
  end
end
