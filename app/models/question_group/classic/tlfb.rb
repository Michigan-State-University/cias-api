# frozen_string_literal: true

class QuestionGroup::Classic::Tlfb < QuestionGroup::Classic
  attribute :title, :string, default: I18n.t('question_group.tlfb.title')

  def index
    session.question_groups.where(type: 'QuestionGroup::Classic::Tlfb').pluck(:id).index(id)
  end

  def title_as_variable
    "#{title.parameterize(separator: '_')}_#{index + 1}"
  end
end
