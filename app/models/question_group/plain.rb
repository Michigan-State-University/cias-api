# frozen_string_literal: true

class QuestionGroup::Plain < QuestionGroup
  attribute :title, :string, default: -> { I18n.t('question_group.plain.title') }
end
