# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::BodyLength
  GSM7_SEGMENT_LENGTHS = [160, 153].freeze
  UCS2_SEGMENT_LENGTHS = [70, 67].freeze
  GSM7_BASIC = "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?¡" \
               'ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà'
  GSM7_EXTENSION = "\f^{}\\[~]|€"
  GSM7_PATTERN = /\A[#{Regexp.escape(GSM7_BASIC + GSM7_EXTENSION)}]*\z/
  GSM7_EXTENSION_PATTERN = /[#{Regexp.escape(GSM7_EXTENSION)}]/

  def self.personal_link_expected_length
    ::PredefinedUserParameter.personal_link('').length + ::PredefinedUserParameter.max_slug_length
  end

  def self.tracked_link_expected_length
    ::SmsLinksUser.tracked_link('').length + ::SmsLinksUser.max_slug_length
  end

  def initialize(body, variables)
    @body = body
    @variables = variables
  end

  def codes
    codes = []
    codes << 'BODY_TOO_LONG' if length > Settings.sms_campaigns.max_body_length
    codes << 'BODY_TOO_MANY_SEGMENTS' if segments > Settings.sms_campaigns.max_segments
    codes
  end

  def length
    expanded.encode('UTF-16LE').bytesize / 2
  end

  def segments
    single, multi = gsm7? ? GSM7_SEGMENT_LENGTHS : UCS2_SEGMENT_LENGTHS
    units = gsm7? ? expanded.length + expanded.scan(GSM7_EXTENSION_PATTERN).size : length
    units <= single ? 1 : units.fdiv(multi).ceil
  end

  def gsm7?
    expanded.match?(GSM7_PATTERN)
  end

  private

  attr_reader :body, :variables

  def expanded
    @expanded ||= begin
      link = 'x' * self.class.tracked_link_expected_length
      text = variables.reduce(body) { |result, variable| result.gsub(SmsLink.token(variable)) { link } }
      "#{text}\n#{'x' * self.class.personal_link_expected_length}"
    end
  end
end
