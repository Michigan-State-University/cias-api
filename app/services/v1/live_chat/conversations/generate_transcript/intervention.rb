# frozen_string_literal: true

class V1::LiveChat::Conversations::GenerateTranscript::Intervention < V1::LiveChat::Conversations::GenerateTranscript
  def generate_transcript
    @csv_content << prepare_headers
    @record.conversations.each do |conversation|
      processed_conversation = process_conversation(conversation)
      (processed_conversation.size...@max_size).each { |_| processed_conversation << nil } if processed_conversation.size < @max_size
      @csv_content << processed_conversation
    end
  end

  def initialize(record)
    super(record)
    @max_size = max_messages_count || 0
  end

  protected

  def prepare_headers
    base_headers + (0...@max_size).map { |i| "Message #{i + 1}" }
  end

  def max_messages_count
    @record.conversations.includes(:messages).map { |conversation| conversation.messages.size }.max
  end
end
