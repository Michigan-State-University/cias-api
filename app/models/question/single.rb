# frozen_string_literal: true

class Question::Single < Question
  before_save :body_has_at_least_one_element
end
