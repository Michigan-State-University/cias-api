# frozen_string_literal: true

class Question::Finish < Question
  attribute :title, :string, default: I18n.t('question.finish.title')
  attribute :subtitle, :string, default: I18n.t('question.finish.subtitle')
  attribute :position, :integer, default: 999_999
  attribute :settings, :json, default: -> { assign_default_values('settings').except('start_autofinish_timer') }

  after_create_commit :after_commit_callbacks

  attr_readonly :position

  def csv_header_names
    []
  end

  def after_commit_callbacks
    set_default_narrator
    initialize_narrator
  end

  def set_default_narrator
    narrator['settings']['character'] = session.current_narrator
    narrator['settings']['extra_space_for_narrator'] = false
    save!
  end
end
