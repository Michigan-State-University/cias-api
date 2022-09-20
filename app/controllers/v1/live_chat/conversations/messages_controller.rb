# frozen_string_literal: true

class V1::LiveChat::Conversations::MessagesController < V1Controller
  def index
    # authorize! :read, LiveChat::Conversation
    conversation = conversation_load

    collection = V1::Paginate.call(conversation.messages.includes(live_chat_interlocutor: [:user]), start_index, end_index)
    render json: V1::LiveChat::MessageSerializer.new(collection)
  end

  private

  def conversation_params
    params.permit(:conversation_id, :start_index, :end_index)
  end

  def conversation_id
    conversation_params[:conversation_id]
  end

  def start_index
    conversation_params[:start_index]&.to_i
  end

  def end_index
    conversation_params[:end_index]&.to_i
  end

  def conversation_load
    LiveChat::Conversation.find(conversation_id)
  end
end
