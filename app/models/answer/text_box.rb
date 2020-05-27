# frozen_string_literal: true

class Answer::TextBox < Answer
  before_save :body_has_one_element
end
