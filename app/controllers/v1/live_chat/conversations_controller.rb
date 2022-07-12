# frozen_string_literal: true

class V1::LiveChat::ConversationsController < V1Controller
  def index
    authorize! :index, LiveChat::Conversation

    render json: V1::LiveChat::ConversationSerializer.new(
      user_conversations,
      { include: %i[live_chat_interlocutors] }
    )
  end

  def create
    authorize! :create, LiveChat::Conversation

    conversation = LiveChat::Conversation.create!(intervention_id: intervention_id)
    create_new_interlocutors(conversation)
    render json: V1::LiveChat::ConversationSerializer.new(conversation)
  end

  private

  def conversation_params
    params.require(:conversation).permit(:intervention_id, user_ids: [])
  end

  def intervention_id
    conversation_params[:intervention_id]
  end

  def interlocutor_ids
    conversation_params[:user_ids] || []
  end

  def create_new_interlocutors(conversation)
    interlocutor_ids.each { |id| LiveChat::Interlocutor.create!(user: User.find(id), conversation: conversation) }
  end

  def user_conversations
    LiveChat::Conversation.active_user_conversations(current_v1_user)
  end
end
