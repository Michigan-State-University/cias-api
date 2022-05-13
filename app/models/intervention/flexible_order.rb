# frozen_string_literal: true

class Intervention::FlexibleOrder < Intervention
  validate :sharing_target, on: %i[update create]

  def can_have_files?
    true
  end

  def module_intervention?
    true
  end

  private

  def sharing_target
    return if shared_to_registered? || shared_to_invited?

    errors.add(:wrong_sharing_target, I18n.t('interventions.flexible_order.wrong_sharing_target', shared_to: shared_to))
  end
end
