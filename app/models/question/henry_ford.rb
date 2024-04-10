# frozen_string_literal: true

class Question::HenryFord < Question::Single
  validates :sms_schedule, absence: true
end
