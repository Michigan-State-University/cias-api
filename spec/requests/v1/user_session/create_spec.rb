# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/user_sessions', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      user_session: {
        session_id: session.id
      }
    }
  end

  context 'when auth' do
    context 'is invalid' do
      before { post v1_user_sessions_path, params: params }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_user_sessions_path, params: params, headers: headers }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'Uid' => user.email
        )
      end
    end
  end

  context 'when params' do
    context 'valid' do
      before do
        post v1_user_sessions_path, params: params, headers: headers
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'invalid' do
      context 'params' do
        before do
          invalid_params = { session: {} }
          post v1_user_sessions_path, params: invalid_params, headers: headers
        end

        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end

  context 'user session' do
    let(:request) { post v1_user_sessions_path, params: params, headers: headers }

    context 'does not exist' do
      it 'returns correct status' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'creates user session' do
        expect { request }.to change(Team, :count).by(1)
      end
    end

    context 'exists' do
      let!(:user_session) { create(:user_session, user: user, session: session) }

      it 'returns correct status' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'does not create user session' do
        request
        expect { request }.to change(Team, :count).by(0)
      end

      it 'returns correct user_session_id' do
        request
        expect(json_response['data']['id']).to eq(user_session.id)
      end
    end
  end
end
