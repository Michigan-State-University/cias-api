# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:researcher_user) { create(:user, :confirmed, :researcher) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) { user.create_new_auth_token }
  let(:researcher_headers) { researcher_user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_users_path }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_users_path, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_users_path, headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        get v1_users_path, headers: headers
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
        get v1_users_path, params: { roles: 'researcher' }, headers: researcher_headers
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
