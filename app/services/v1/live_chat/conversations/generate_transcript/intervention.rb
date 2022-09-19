# frozen_string_literal: true

class V1::LiveChat::Conversations::GenerateTranscript::Intervention < V1::LiveChat::Conversations::GenerateTranscript
  def generate_transcript
    @record.conversations.each { |conversation| concat_result(prepare_file_header(conversation), process_conversation(conversation)) }
    @csv_content.flatten!
  end
end
