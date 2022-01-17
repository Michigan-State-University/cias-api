# frozen_string_literal: true

class QuestionGroup::Tlfb < QuestionGroup
  attribute :title, :string, default: I18n.t('question_group.tlfb.title')
end
