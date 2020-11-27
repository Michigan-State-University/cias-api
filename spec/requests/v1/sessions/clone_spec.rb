# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sessions/:id/clone', type: :request do
  let(:user) { create(:user, :confirmed, :researcher) }
  let(:session) { create(:session) }
  let(:headers) { user.create_new_auth_token }

  context 'when auth' do
    context 'is invalid' do
      before { post v1_clone_session_path(id: session.id) }

      it 'response contains generated uid token' do
        expect(response.headers.to_h).to include(
          'uid' => include('@guest.true')
        )
      end
    end

    context 'is valid' do
      before { post v1_clone_session_path(id: session.id), headers: headers }

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
        post v1_clone_session_path(id: session.id), headers: headers
      end

      it { expect(response).to have_http_status(:created) }
      it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
    end

    context 'is JSON and parse' do
      before do
        post v1_clone_session_path(id: session.id), headers: headers
      end

      it 'success to Hash' do
        expect(json_response.class).to be(Hash)
      end
    end
  end

  context 'not found' do
    let(:invalid_session_id) { '1' }

    before do
      post v1_clone_session_path(id: invalid_session_id), headers: headers
    end

    it 'has correct failure http status' do
      expect(response).to have_http_status(:not_found)
    end

    it 'has correct failure message' do
      expect(json_response['message']).to eq("Couldn't find Session with 'id'=#{invalid_session_id}")
    end
  end

  context 'cloned' do
    before do
      post v1_clone_session_path(id: session.id), headers: headers
    end

    let(:session_was) do
      session.attributes.except('id', 'created_at', 'updated_at', 'position')
    end
    let(:session_cloned) do
      json_response['data']['attributes'].except('id', 'created_at', 'updated_at', 'position')
    end

    it 'has correct http code' do
      expect(response).to have_http_status(:created)
    end

    it 'origin and outcome same' do
      expect(session_was).to eq(session_cloned)
    end

    it 'has correct position' do
      expect(json_response['data']['attributes']['position']).to eq(2)
    end

    it 'has correct number of sessions' do
      expect(session.intervention.sessions.size).to eq(2)
    end
  end
end
