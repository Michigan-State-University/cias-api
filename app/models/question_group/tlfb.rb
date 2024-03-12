# frozen_string_literal: true

class QuestionGroup::Tlfb < QuestionGroup
  attribute :title, :string, default: -> { I18n.t('question_group.tlfb.title') }

  def index
    session.question_groups.where(type: 'QuestionGroup::Tlfb').pluck(:id).index(id)
  end

  def title_as_variable
    "#{title.parameterize(separator: '_')}_#{index + 1}"
  end
end
