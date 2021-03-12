# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UserSession', type: :request do
  let!(:intervention) { create(:intervention, :published) }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let!(:params) do
    {
      user_session: {
        session_id: session.id
      }
    }
  end

  let(:request) { post v1_user_sessions_path, params: params, headers: headers }

  describe 'POST /v1/user_sessions' do
    context 'when user is logged' do
      let!(:user) { create(:user, :confirmed, :admin) }
      let!(:headers) { user.create_new_auth_token }

      it 'does not create new user' do
        expect { request }.to change(User, :count).by(0)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is not logged' do
      let(:guest) { User.limit_to_roles('guest').last }

      it 'create new guest user' do
        expect { request }.to change(User, :count).by(1)
        expect(guest).not_to be(nil)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
