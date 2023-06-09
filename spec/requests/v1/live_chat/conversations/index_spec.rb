# frozen_string_literal: true

RSpec.describe 'GET /v1/live_chat/conversations', type: :request do
  let!(:user) { create(:user, :confirmed, :navigator) }
  let!(:other_user) { create(:user, :confirmed, :admin) }
  let(:intervention) { create(:intervention, user: user) }
  let!(:interlocutors) { conversations.map { |conv| create(:live_chat_interlocutor, user: user, conversation: conv) } }
  let!(:other_interlocutors) { conversations.map { |conv| create(:live_chat_interlocutor, user: other_user, conversation: conv) } }
  let!(:conversation) { create(:live_chat_conversation, intervention: intervention) }
  let!(:conversations) { create_list(:live_chat_conversation, 4, intervention: intervention) }
  let!(:messages) do
    [
      create(:live_chat_message, conversation: conversations[0], live_chat_interlocutor: interlocutors[0]),
      create(:live_chat_message, conversation: conversations[1], live_chat_interlocutor: interlocutors[1]),
      create(:live_chat_message, conversation: conversations[2], live_chat_interlocutor: interlocutors[2]),
      create(:live_chat_message, conversation: conversations[3], live_chat_interlocutor: interlocutors[3])
    ]
  end

  let!(:archived_conversations) { create_list(:live_chat_conversation, 3, intervention_id: intervention.id, archived_at: DateTime.now) }
  let!(:interlocutors_archive) { archived_conversations.map { |conv| create(:live_chat_interlocutor, user: user, conversation: conv) } }

  let(:request) do
    get v1_live_chat_conversations_path, headers: user.create_new_auth_token
  end

  before do
    allow_any_instance_of(V1Controller).to receive(:current_v1_user).and_return(user)
  end

  context 'returns correct conversation data' do
    before do
      intervention.navigators << user
      request
    end

    it 'returns correct amount of conversations' do
      expect(json_response['data'].length).to eq conversations.length
    end

    it 'returns correct status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct conversations' do
      expect(json_response['data'].pluck('id')).to match_array(conversations.pluck(:id))
    end

    it 'returns correct interlocutor data' do
      expect(json_response['data'].map { |h| h['relationships']['live_chat_interlocutors']['data'].length }).to eq [2, 2, 2, 2]
    end

    it 'returns last message sent in a conversation' do
      expected = messages.map do |message|
        {
          'id' => message.id,
          'content' => message.content,
          'conversation_id' => message.conversation_id,
          'interlocutor_id' => message.live_chat_interlocutor.id,
          'is_read' => false
        }
      end
      expect(json_response['data'].map { |h| h['attributes'] }.pluck('last_message').map { |h| h.except('created_at') }).to eq expected
    end
  end

  context 'returns only archived conversations' do
    let(:param) { { archived: true } }
    let(:request) { get v1_live_chat_conversations_path, params: param, headers: user.create_new_auth_token }

    before { intervention.navigators << user }

    it 'returns only archived data' do
      request
      expect(json_response['data'].length).to eq archived_conversations.length
    end
  end

  context 'when user don\'t have permission' do
    let(:health_clinic_admin) { create(:user, :health_clinic_admin, :confirmed) }

    before do
      allow_any_instance_of(V1Controller).to receive(:current_v1_user).and_return(health_clinic_admin)
    end

    it {
      request
      expect(response).to have_http_status(:forbidden)
    }
  end

  context 'when user is not a navigator in the intervention' do
    before do
      intervention.intervention_navigators.destroy_all
      request
    end

    it 'returns no data from the intervention' do
      expect(json_response['data'].length).to eq 0
    end
  end
end
