# frozen_string_literal: true

class QuestionGroup::Initial < QuestionGroup
  has_one :question_initial, inverse_of: :question_group, class_name: '::Question::SmsInformation',
                            foreign_key: :question_group_id, dependent: :destroy

  attribute :title, :string, default: I18n.t('question_group.initial.title')
  attribute :position, :integer, default: 0

  attr_readonly :position
end
