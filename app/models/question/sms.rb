# frozen_string_literal: true

class Question::Sms < Question
  belongs_to :question_group, inverse_of: :questions, touch: true, counter_cache: true, class_name: 'QuestionGroup::Sms'
end
