# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH  /v1/user_sessions/:user_session_id/quick_exit', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:shared_to) { :anyone }
  let(:status) { :published }
  let(:intervention) { create(:intervention, user: researcher, status: status, shared_to: shared_to) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user_session) { create(:user_session, user: participant, session: session) }
  let(:headers) { participant.create_new_auth_token }
  let(:request) { patch v1_user_session_quick_exit_path(user_session.id), headers: headers }

  before { request }

  context 'when the intervention is paused' do
    let(:user) { researcher }

    it_behaves_like 'paused intervention'
  end

  context 'when user want to quick exit form own user session' do
    it 'update correct field' do
      expect(user_session.reload.quick_exit).to be true
    end

    it 'return correct status' do
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when someone else wants to update user_session' do
    let(:other_participant) { create(:user, :confirmed, :participant) }
    let(:headers) { other_participant.create_new_auth_token }

    it 'return correct status' do
      expect(response).to have_http_status(:forbidden)
    end

    it 'return correct message' do
      expect(json_response['message']).to eql('You are not authorized to access this page.')
    end
  end
end
