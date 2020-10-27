# frozen_string_literal: true

class Question::Finish < Question
  include PreventDestroy

  attribute :title, :string, default: I18n.t('question.finish.title')
  attribute :subtitle, :string, default: I18n.t('question.finish.subtitle')
  attribute :position, :integer, default: 999_999
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  attr_readonly :position
end
