# frozen_string_literal: true

module RedirectToWebApp
  private

  def redirect_to_web_app(message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV.fetch('WEB_URL', nil)}?#{message.to_query}", allow_other_host: true
  end
end
