# frozen_string_literal: true

class Answer::Multiple < Answer
  before_save :body_has_at_least_one_element
end
