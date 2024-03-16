# frozen_string_literal: true

class QuestionGroup::Sms < QuestionGroup
  belongs_to :session, inverse_of: :question_groups, touch: true, class_name: 'Session::Sms'
end
