# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'UserSession RA creation guard', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, :published, user: researcher, shared_to: :anyone) }
  let!(:ra_session) { create(:ra_session, intervention: intervention) }
  let(:participant) { create(:user, :confirmed, :participant) }

  describe 'POST /v1/user_sessions (create)' do
    let(:params) do
      { user_session: { session_id: ra_session.id } }
    end

    context 'when participant tries to create an RA UserSession' do
      it 'returns forbidden' do
        post v1_user_sessions_path, params: params, headers: participant.create_new_auth_token
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /v1/fetch_or_create_user_sessions (show_or_create)' do
    let(:params) do
      { user_session: { session_id: ra_session.id } }
    end

    context 'when participant tries to create an RA UserSession' do
      it 'returns forbidden' do
        post v1_fetch_or_create_user_sessions_path, params: params, headers: participant.create_new_auth_token
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
