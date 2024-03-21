# frozen_string_literal: true

class Question::Classic::Information < Question::Classic
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def csv_header_names
    []
  end
end
