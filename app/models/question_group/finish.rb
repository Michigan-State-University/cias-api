# frozen_string_literal: true

class QuestionGroup::Finish < QuestionGroup
  has_one :question_finish, inverse_of: :question_group, class_name: '::Question::Finish',
                            foreign_key: :question_group_id, dependent: :destroy

  attribute :title, :string, default: I18n.t('question_group.finish.title')
  attribute :position, :integer, default: 999_999

  attr_readonly :position
end
