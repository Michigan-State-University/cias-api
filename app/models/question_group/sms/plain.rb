# frozen_string_literal: true

class QuestionGroup::Sms::Plain < QuestionGroup::Sms
  attribute :title, :string, default: I18n.t('question_group.plain.title')
end
