# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/users/invitations', type: :request do
  let(:request) { post v1_invitations_path, params: params, headers: headers }
  let(:params)  do
    {
      invitation: {
        email: 'test@example.com',
        role: 'researcher'
      }
    }
  end

  context 'when autenticated as guest user' do
    let(:guest_user) { create(:user, :guest) }
    let(:headers)    { guest_user.create_new_auth_token }

    it 'returns forbidden status' do
      request

      expect(response).to have_http_status(:forbidden)
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end

  context 'when auhtenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers)    { admin_user.create_new_auth_token }

    context 'when valid params provided' do
      it 'returns created status' do
        request

        expect(response).to have_http_status(:created)
        expect(json_response['email']).to eq 'test@example.com'
      end
    end

    context 'when email that already exists in system provided' do
      let!(:existing_user) { create(:user, :researcher, email: 'test@example.com') }

      it 'returns unprocessable_entity status' do
        request

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq 'Email already exists in system.'
      end
    end

    context 'when invalid params provided' do
      let(:params) do
        {
          invitation: {
            email: 'INVALID_EMAIL',
            role: 'INVALID_ROLE'
          }
        }
      end

      it 'returns unprocessable_entity status' do
        request

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq 'Email is not an email'
      end
    end
  end
end
