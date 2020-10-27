# frozen_string_literal: true

class QuestionGroup::Default < QuestionGroup
  include PreventDestroy

  attribute :title, :string, default: I18n.t('question_group.default.title')
  attribute :position, :integer, default: 0

  attr_readonly :position
end
