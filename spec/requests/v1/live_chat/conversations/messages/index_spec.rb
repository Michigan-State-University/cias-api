# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/conversations/:conversation_id/messages', type: :request do
  let!(:conversation) { create(:live_chat_conversation) }
  let(:interlocutor) { create(:live_chat_interlocutor, user: user, conversation: conversation) }
  let!(:messages) { create_list(:live_chat_message, 4, conversation: conversation, live_chat_interlocutor: interlocutor) }
  let!(:user) { create(:user, :admin, :confirmed) }
  let(:request) do
    get v1_live_chat_conversation_messages_path(conversation_id: conversation.id), params: params, headers: user.create_new_auth_token
  end
  let(:params) { {} }

  before do
    request
  end

  context 'Correctly returns latest messages' do
    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct amount of messages' do
      expect(json_response['data'].length).to eq messages.length
    end

    it 'returns correct messages' do
      expect(json_response['data'].pluck('id')).to match_array(messages.pluck(:id))
    end
  end

  context 'Correctly returns messages based on pagination params' do
    let(:params) do
      {
        start_index: 0,
        end_index: 2
      }
    end

    it 'returns correct amount of messages' do
      expect(json_response['data'].length).to be 3
    end

    it 'returns correct messages' do
      expect(json_response['data'].pluck('id')).to match_array(messages.sort_by!(&:created_at).reverse!.pluck(:id).slice(0, 3))
    end
  end
end
