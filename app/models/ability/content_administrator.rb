# frozen_string_literal: true

class Ability::ContentAdministrator < Ability::Interface
  def definition
    super
    content_administrator if role?('content_administrator')
  end

  private

  def content_administrator; end
end
