# frozen_string_literal: true

class Question::Tlfb < Question
  validate :tlfb_validation
  before_save :assign_tlfb_defaults

  protected

  def tlfb_validation; end

  def assign_tlfb_defaults
    self.subtitle = false
    self.title = false
    settings['proceed_button'] = false
  end
end
