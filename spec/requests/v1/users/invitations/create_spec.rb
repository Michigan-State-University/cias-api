# frozen_string_literal: true

require 'rails_helper'

describe 'POST /v1/users/invitations', type: :request do
  let(:request) { post v1_invitations_path, params: params, headers: headers }
  let(:params) do
    {
      invitation: {
        email: 'test@example.com',
        role: 'researcher'
      }
    }
  end

  %w[guest participant researcher e_intervention_admin team_admin organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context "when authenticated as #{role}" do
      let(:current_user) { create(:user, role) }
      let(:headers) { current_user.create_new_auth_token }

      before do
        request
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns correct error message' do
        expect(json_response['message']).to eq 'You are not authorized to access this page.'
      end
    end
  end

  context 'when authenticated as admin user' do
    let(:admin_user) { create(:user, :admin) }
    let(:headers) { admin_user.create_new_auth_token }

    context 'when valid params provided' do
      before do
        request
      end

      it 'returns created status' do
        expect(response).to have_http_status(:created)
      end

      it 'returns correct email' do
        expect(json_response['data']['attributes']['email']).to eq 'test@example.com'
      end
    end

    context 'when email that already exists in system provided' do
      let!(:existing_user) { create(:user, :researcher, email: 'test@example.com') }

      before do
        request
      end

      it 'returns unprocessable_entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns correct error message' do
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

      before do
        request
      end

      it 'returns unprocessable_entity status' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns correct error message' do
        expect(json_response['error']).to include('Email is not an email', 'Terms must be accepted')
      end
    end
  end
end
