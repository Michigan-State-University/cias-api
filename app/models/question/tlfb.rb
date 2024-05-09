# frozen_string_literal: true

class Question::Tlfb < Question
  attribute :settings, :json, default: -> { {} }

  validates :accepted_answers, absence: true

  def prepare_to_display(_answers_var_values = nil)
    apply_config(question_group.questions.first.body)
    self
  end

  def apply_config(config_body)
    body['config'] = config_body
  end

  def csv_header_names
    []
  end

  def ability_to_clone?
    false
  end
end
