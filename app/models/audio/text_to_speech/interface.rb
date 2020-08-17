# frozen_string_literal: true

module Audio::TextToSpeech::Interface
  extend ActionDispatch::Routing::UrlFor
  extend Rails.application.routes.url_helpers
  include Rails.application.routes.url_helpers

  def synthesize
    raise NotImplementedError, 'subclass did not define #synthesize'
  end
end
