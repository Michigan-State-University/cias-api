# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { delete v1_user_path(id: alter_user.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { delete v1_user_path(id: alter_user.id), headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when response' do
    context 'is success' do
      before do
        delete v1_user_path(id: alter_user.id), headers: headers
      end

      it { expect(response).to have_http_status(:no_content) }
    end
  end

  context 'not found' do
    before do
      delete v1_user_path(id: 'invalid'), headers: headers
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end
