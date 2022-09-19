# frozen_string_literal: true

class LiveChat::GenerateConversationTranscriptJob < ApplicationJob
  def perform(conversation_id, user_id)
    user = User.find(user_id)
    conversation = LiveChat::Conversation.find(conversation_id)

    result = V1::LiveChat::Conversations::GenerateTranscript::Conversation.call(conversation)

    MetaOperations::FilesKeeper.new(
      stream: result.to_csv, add_to: conversation,
      macro: :transcript, ext: :csv, type: 'text/csv',
      filename: transcript_file_name(conversation.intervention)
    ).execute

    return unless user.email_notification

    LiveChat::TranscriptMailer.conversation_transcript(user.email, conversation).deliver_now
  end

  private

  def transcript_file_name(intervention)
    timestamp = Time.current.in_time_zone(ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')).
      strftime(ENV.fetch('FILE_TIMESTAMP_NOTATION', '%m-%d-%Y_%H%M'))
    "#{timestamp}_#{intervention.name.parameterize.underscore[..12]}"
  end
end
