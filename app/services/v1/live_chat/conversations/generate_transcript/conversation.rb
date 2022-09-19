# frozen_string_literal: true

class V1::LiveChat::Conversations::GenerateTranscript::Conversation < V1::LiveChat::Conversations::GenerateTranscript
  def generate_transcript
    concat_result(prepare_file_header(@record), process_conversation(@record))
    @csv_content.flatten!
  end
end
