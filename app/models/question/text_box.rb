# frozen_string_literal: true

class Question::TextBox < Question
  before_save :body_has_one_element
end
