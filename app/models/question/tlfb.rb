# frozen_string_literal: true

class Question::Tlfb < Question
  validate :tlfb_validation

  protected

  def tlfb_validation; end
end
