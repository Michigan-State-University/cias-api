# frozen_string_literal: true

module Auth::WebAppRedirectUrlCheck
  include RedirectToWebApp

  def self.allowed?(url)
    target = parse(url)
    web_app = parse(ENV.fetch('WEB_URL', nil))
    return false if target.nil? || web_app.nil?

    target.scheme == web_app.scheme && target.host.casecmp?(web_app.host) && target.port == web_app.port
  end

  def self.parse(url)
    return unless url.is_a?(String)

    uri = URI.parse(url)
    uri if uri.host.present? && uri.userinfo.nil?
  rescue URI::InvalidURIError
    nil
  end
  private_class_method :parse

  protected

  def redirect_options
    Auth::WebAppRedirectUrlCheck.allowed?(redirect_url_to_check) ? { allow_other_host: true } : {}
  end

  private

  def redirect_url_to_check
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def validate_web_app_redirect_url
    url = redirect_url_to_check
    return if url.nil? || Auth::WebAppRedirectUrlCheck.allowed?(url)

    Rails.logger.warn("Redirect URL rejected in #{controller_path}##{action_name}")

    if request.get?
      redirect_to_web_app(error: I18n.t('users.redirect_url.invalid_link'))
    else
      render_error(422, I18n.t('users.redirect_url.not_allowed'))
    end
  end
end
