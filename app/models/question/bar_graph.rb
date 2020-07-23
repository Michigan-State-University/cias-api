# frozen_string_literal: true

class Question::BarGraph < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }
end
