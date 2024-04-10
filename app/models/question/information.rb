# frozen_string_literal: true

class Question::Information < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  validates :sms_schedule, absence: true

  def csv_header_names
    []
  end
end
