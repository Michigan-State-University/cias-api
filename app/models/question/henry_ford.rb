# frozen_string_literal: true

class Question::HenryFord < Question::Single
  validates :accepted_answers, absence: true
end
