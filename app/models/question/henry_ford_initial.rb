# frozen_string_literal: true

class Question::HenryFordInitial < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def csv_header_names
    []
  end

  def ability_to_clone?
    false
  end
end
