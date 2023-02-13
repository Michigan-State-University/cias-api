# frozen_string_literal: true

class V1::LiveChat::Conversations::GenerateTranscript::Conversation < V1::LiveChat::Conversations::GenerateTranscript
  def generate_transcript
    @csv_content << prepare_headers
    @csv_content << process_conversation(@record)
  end

  protected

  def prepare_headers
    base_headers + @record.messages.map.with_index { |_, index| "Message #{index + 1}" }
  end
end
