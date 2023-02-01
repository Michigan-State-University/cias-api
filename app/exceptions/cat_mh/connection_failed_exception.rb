# frozen_string_literal: true

class CatMh::ConnectionFailedException < StandardError
  # rubocop:disable Lint/MissingSuper
  def initialize(title_text, body_text, button_text)
    @title_text = title_text
    @body_text = body_text
    @button_text = button_text
  end
  # rubocop:enable Lint/MissingSuper
  attr_reader :title_text, :body_text, :button_text
end
