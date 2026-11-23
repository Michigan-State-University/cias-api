# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::TextCodes
  FORBIDDEN_CHARACTERS = /[\p{Cc}&&[^\n\r\t]]|[​-‍⁠﻿]/

  def self.call(body, links)
    new(body, links).codes
  end

  def initialize(body, links)
    @body = body
    @links = links
  end

  def codes
    body_codes + link_codes
  end

  private

  attr_reader :body, :links

  def variables
    @variables ||= links.pluck(:variable).compact
  end

  def body_codes
    return ['BODY_BLANK'] if body.blank?
    return ['BODY_FORBIDDEN_CHARACTERS'] if body.match?(FORBIDDEN_CHARACTERS)

    V1::PredefinedParticipants::SmsCampaigns::BodyLength.new(body, variables).codes
  end

  def link_codes
    used = body.scan(SmsLink::TOKEN_PATTERN).flatten.uniq
    codes = []
    codes << 'DUPLICATE_LINK_VARIABLE' if variables.uniq.size < variables.size
    codes << 'UNKNOWN_LINK_VARIABLE' if (used - variables).any?
    codes << 'UNUSED_LINK_VARIABLE' if (variables - used).any?
    codes << 'INVALID_LINK_TYPE' if links.any? { |link| link[:link_type] && !SmsLink.link_types.key?(link[:link_type]) }
    codes
  end
end
