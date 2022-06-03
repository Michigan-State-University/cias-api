# frozen_string_literal: true

class V1::LiveChat::ConversationsController < V1Controller
  def index
    render json: V1::LiveChat::ConversationSerializer.new(user_conversations)
  end

  private

  def user_conversations
    LiveChat::Conversation.includes(:live_chat_interlocutors).where(live_chat_interlocutors: { user_id: current_v1_user.id })
  end
end
