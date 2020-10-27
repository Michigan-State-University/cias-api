# frozen_string_literal: true

module PreventDestroy
  extend ActiveSupport::Concern

  included do
    before_destroy :interrupt_destroy
  end

  private

  def interrupt_destroy
    errors.add(:undestroyable, I18n.t('activerecord.errors.messages.undestroyable'))
    throw :abort
  end
end
