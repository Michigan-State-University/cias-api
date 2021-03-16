# frozen_string_literal: true

class Question::ThirdParty < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => false }
    )
  end

  def csv_header_names
    []
  end
end
