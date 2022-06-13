# frozen_string_literal: true

RSpec.describe 'POST /v1/live_chat/conversations', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:params) do
    {
      user_ids: [admin.id, participant.id]
    }
  end

  let(:request) do
    post v1_live_chat_conversations_path, params: params, headers: admin.create_new_auth_token
  end

  before { request }

  it 'returns correct status code (OK)' do
    expect(response).to have_http_status(:ok)
  end

  it 'returns correct conversation data (with 2 interlocutors)' do
    expect(json_response['data']['attributes']['interlocutors']['data'].size).to eq 2
  end
end
