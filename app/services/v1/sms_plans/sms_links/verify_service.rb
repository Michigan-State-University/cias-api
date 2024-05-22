# frozen_string_literal: true

class V1::SmsPlans::SmsLinks::VerifyService
  attr_reader :sms_links_user

  def initialize(sms_links_user)
    @sms_links_user = sms_links_user
  end

  def call
    sms_links_user.add_timestamp

    { url: sms_links_user.sms_link.url }
  end
end
