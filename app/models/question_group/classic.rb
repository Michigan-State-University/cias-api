# frozen_string_literal: true

class QuestionGroup::Classic < QuestionGroup
  belongs_to :session, inverse_of: :question_groups, touch: true, class_name: 'Session::Classic'
end
