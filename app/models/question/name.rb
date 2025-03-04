# frozen_string_literal: true

class Question::Name < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super.merge(
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

  private

  def special_variable?(_var)
    true
  end
end
