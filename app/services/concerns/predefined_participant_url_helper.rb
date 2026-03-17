# frozen_string_literal: true

module PredefinedParticipantUrlHelper
  INTERVENTION_URL_REGEX = %r{
    #{Regexp.escape(ENV.fetch('WEB_URL'))}
    /interventions/
    [^/\s]+
    (?:
      /invite
      |
      /sessions/[^/\s]+/fill
    )
    (?:\?[^\s]*)?
  }x

  ANCHORED_INTERVENTION_URL_REGEX = /\A#{INTERVENTION_URL_REGEX}\z/

  def append_pid_to_intervention_urls(content, user)
    return content unless user&.role?('predefined_participant')

    content.gsub(INTERVENTION_URL_REGEX) do |url|
      append_pid_to_intervention_url(url, user)
    end
  end

  def append_pid_to_intervention_url(url, user)
    return url unless user&.role?('predefined_participant')
    return url unless url.match?(ANCHORED_INTERVENTION_URL_REGEX)

    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || '')
    params << ['pid', user.predefined_user_parameter.slug] unless params.any? { |k, _| k == 'pid' }
    uri.query = URI.encode_www_form(params)
    uri.to_s
  rescue URI::InvalidURIError
    url
  end
end
