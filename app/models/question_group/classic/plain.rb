# frozen_string_literal: true

class QuestionGroup::Classic::Plain < QuestionGroup::Classic
  attribute :title, :string, default: I18n.t('question_group.plain.title')
end
