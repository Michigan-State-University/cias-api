# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { get v1_user_path(id: alter_user.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { get v1_user_path(id: alter_user.id), headers: headers }

      it 'response contains proper uid token' do
        expect(response.headers.to_h).to include(
          'uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is JSON' do
      before do
        get v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'contains' do
      before do
        get v1_user_path(id: alter_user.id), headers: headers
      end

      it 'to hash success' do
        expect(json_response.class).to be(Hash)
      end

      it 'key question' do
        expect(json_response['data']['type']).to eq('user')
      end
    end
  end
end
