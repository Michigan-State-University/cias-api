# frozen_string_literal: true

class Question::Name < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true }
    )
  end

  def csv_header_names
    ['metadata.phonetic_name']
  end

  def question_variables
    ['.:name:.']
  end

  def ability_to_clone?
    false
  end
end
