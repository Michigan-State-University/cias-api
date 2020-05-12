# frozen_string_literal: true

class Ability::ContentAdministrator < Ability::Base
  def definition
    super
    content_administrator if role?(class_name)
  end

  private

  def content_administrator; end
end
