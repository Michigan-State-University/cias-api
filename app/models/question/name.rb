# frozen_string_literal: true

class Question::Name < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }
end
