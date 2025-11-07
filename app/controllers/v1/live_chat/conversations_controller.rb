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

  def generate_transcript
    authorize! :generate_transcript, LiveChat::Conversation

    return render status: :method_not_allowed unless can_generate_transcript?

    LiveChat::GenerateTranscriptJob.perform_later(
      conversation_load.id, LiveChat::Conversation, :transcript, conversation_load.intervention.name, current_v1_user.id
    )

    render status: :created
  end

  private

  def can_generate_transcript?
    conversation = conversation_load
    return true unless conversation.transcript.attached?

    conversation.archived? ? (conversation.transcript.blob.created_at < conversation.archived_at) : true
  end

  def conversation_load
    @conversation_load ||= LiveChat::Conversation.accessible_by(current_ability).find(params[:conversation_id])
  end

  def archived_filter_params
    params.permit(:archived)
  end

  def archived?
    ActiveRecord::Type::Boolean.new.cast(archived_filter_params[:archived] || false)
  end

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
    LiveChat::Conversation.navigator_conversations(current_v1_user, archived?)
  end

  def intervention_load
    Intervention.accessible_by(current_ability).find(intervention_id)
  end
end
