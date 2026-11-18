# frozen_string_literal: true

class V1::SmsLinks::VerifyService
  include ::PredefinedParticipantUrlHelper

  attr_reader :sms_links_user

  def self.call(sms_links_user)
    new(sms_links_user).call
  end

  def initialize(sms_links_user)
    @sms_links_user = sms_links_user
  end

  def call
    sms_links_user&.add_timestamp

    url = sms_links_user&.sms_link&.url
    return url if url.blank?

    append_pid_to_intervention_url(url, sms_links_user.user)
  end
end
