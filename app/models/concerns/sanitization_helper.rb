# frozen_string_literal: true

module SanitizationHelper
  def sanitize_string(str)
    clean = Loofah.fragment(str).scrub!(:prune).to_s
    ERB::Util.html_escape(clean)
  end
end
