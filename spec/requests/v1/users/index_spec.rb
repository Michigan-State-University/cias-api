# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:researcher_user) { create(:user, :confirmed, :researcher) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:researcher_headers) do
    researcher_user.create_new_auth_token
  end

  context 'when endpoint is available' do
    before { get v1_users_path }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context 'when auth' do
    context 'is without credentials' do
      before do
        get v1_users_path
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is with invalid credentials' do
      before do
        headers.delete('access-token')
        get v1_users_path, params: {}, headers: headers
      end

      it { expect(response).to have_http_status(:unauthorized) }

      it 'response is without user token' do
        expect(response.headers['access-token']).to be_nil
      end
    end

    context 'is valid' do
      before do
        get v1_users_path, params: {}, headers: headers
      end

      it { expect(response).to have_http_status(:success) }

      it 'and response contains user token' do
        expect(response.headers['access-token']).not_to be_nil
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_users_path, params: {}, headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_users_path, params: {}, headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end
  end

  context 'with specific roles' do
    context 'one role' do
      before do
        get v1_users_path, params: { roles: 'admin' }, headers: headers
      end

      let(:admin_role) do
        role = []
        json_response['data'].each do |user|
          role.push(user['attributes']['roles'])
        end
        role.flatten!
        role.uniq!
        role
      end

      it 'include admin role' do
        expect(admin_role).to include('admin')
      end

      it 'roles size 1' do
        expect(admin_role.size).to eq(1)
      end
    end

    context 'researcher role' do
      before do
        get v1_users_path, params: { roles: 'researcher,admin' }, headers: researcher_headers
      end

      let(:researcher_role) do
        role = []
        json_response['data'].each do |user|
          role.push(user['attributes']['roles'])
        end
        role.flatten!
        role.uniq!
        role
      end

      it 'include researcher role' do
        expect(researcher_role).to include('researcher')
      end

      it 'roles size 1' do
        expect(researcher_role.size).to eq(1)
      end
    end
  end
end
