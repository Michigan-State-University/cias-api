# frozen_string_literal: true

class Intervention::FixedOrder < Intervention
  validate :sharing_target, on: %i[create update]

  def module_intervention?
    true
  end

  def can_have_files?
    true
  end

  private

  def sharing_target
    return if shared_to_registered? || shared_to_invited?

    errors.add(:wrong_sharing_target, I18n.t('interventions.fixed_order.wrong_sharing_target', shared_to: shared_to))
  end
end
