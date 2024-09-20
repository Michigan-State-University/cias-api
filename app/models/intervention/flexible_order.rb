# frozen_string_literal: true

class Intervention::FlexibleOrder < Intervention
  def can_have_files?
    true
  end

  def module_intervention?
    true
  end
end
