# frozen_string_literal: true

class Ability::ContentAdmin < Ability::Base
  def definition
    super
    content_admin if role?(class_name)
  end

  private

  def content_admin; end
end
