# frozen_string_literal: true

class Question::ParticipantReport < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super.merge(
      { 'required' => true }
    )
  end

  def csv_header_names
    []
  end

  def question_variables
    [body['variable']['name']]
  end

  def extract_variables_from_params(params)
    variable_name = params.dig(:body, :variable, :name)
    return [] if variable_name.blank?

    [{ 'name' => variable_name }]
  end
end
