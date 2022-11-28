# frozen_string_literal: true

require 'csv'

class V1::LiveChat::Conversations::GenerateTranscript
  include CsvHelper
  include DateTimeInterface
  include CsvHelper
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
      @csv_content.each { |row| csv << row }
    end
  end

  def generate_transcript
    raise NotImplementedError, "Subclass did not define #{__method__} method"
  end

  protected

  def prepare_headers
    raise NotImplementedError, "Subclass did not define #{__method__} method"
  end

  def process_conversation(conversation)
    timestamp = to_csv_timestamp(conversation.created_at)
    [
      conversation.intervention.name, conversation.participant_location_history, conversation.other_user.id,
      timestamp.strftime('%m/%d/%Y'), timestamp.strftime('%I:%M:%S %p'), conversation_duration(conversation),
      *conversation.messages.map { |message| process_message(message) }
    ]
  end

  def base_headers
    # headers are: intervention name, location history (ids), participant id, conversation date, initiation time, duration, and messages
    # (pad all of the shorter arrays to max)
    ['Intervention name', 'Location history', 'Participant ID', 'Date EST', 'Inititation time EST', 'Duration']
  end

  def process_message(message)
    "[#{message.user.navigator? ? 'N' : 'P'}] \"#{message.content}\""
  end

  def conversation_duration(conversation)
    conversation.archived ? time_diff(conversation.created_at, conversation.updated_at) : nil
  end
end
