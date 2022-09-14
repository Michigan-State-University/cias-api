# frozen_string_literal: true

require 'csv'

class V1::LiveChat::Conversations::GenerateTranscript
  attr_reader :csv_content

  def self.call(record)
    new(record).call
  end

  def initialize(record)
    @record = record
    @csv_content = []
  end

  def call
    generate_transcript
    self
  end

  def to_csv
    CSV.generate do |csv|
      @csv_content.each { |row| csv << [row] }
    end
  end

  def generate_transcript
    raise NotImplementedError, "Subclass did not define #{__method__} method"
  end

  protected

  def prepare_file_header(conversation)
    navigator = conversation.users.limit_to_roles('navigator').first
    participant = conversation.users.limit_to_roles(%w[participant guest]).first
    [
      "\"Intervention: #{conversation.intervention.name}\"",
      "\"Navigator: #{navigator.full_name} <#{navigator.email}>\"",
      "\"Participant: #{participant.guest? ? "<#{participant.id}>" : "#{participant.full_name} <#{participant.email}>"}\""
    ]
  end

  def process_conversation(conversation)
    conversation.messages.map { |message| process_message(message) }
  end

  def process_message(message)
    prefix = message.user.navigator? ? 'N' : 'P'
    "#{prefix},#{message.created_at.strftime(ENV.fetch('FILE_TIMESTAMP_NOTATION', '%m-%d-%Y_%H%M'))},\"#{message.content}\""
  end

  def concat_result(header, transcript)
    @csv_content << header
    @csv_content << transcript
  end
end
