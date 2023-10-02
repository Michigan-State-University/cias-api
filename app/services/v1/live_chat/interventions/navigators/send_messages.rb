# frozen_string_literal: true

class V1::LiveChat::Interventions::Navigators::SendMessages
  def self.call(intervention, message_type, exclude_user = nil)
    new(intervention, message_type, exclude_user).call
  end

  def initialize(intervention, message_type, excluded_user)
    @intervention = intervention
    @message_type = message_type
    @excluded_user = excluded_user
  end

  def call
    users = intervention.navigators + [intervention.user]
    users.delete(excluded_user)

    users.uniq.each do |user|
      case message_type
      when 'call_out'
        LiveChat::NavigatorMailer.navigator_call_out_mail(user.email, intervention).deliver_now
        send_sms(user, call_out_sms_content(intervention))
      when 'cancel_call_out'
        LiveChat::NavigatorMailer.participant_handled_mail(user.email, intervention).deliver_now
        send_sms(user, participant_handled_sms_content(intervention))
      end
    end
  end

  attr_accessor :intervention, :message_type, :excluded_user

  private

  def send_sms(user, content)
    user_phone_number = user.phone&.full_number.presence
    return unless user_phone_number

    sms = Message.create(phone: user_phone_number, body: content)
    Communication::Sms.new(sms.id).send_message
  end

  def call_out_sms_content(intervention)
    I18n.t('navigator_mailer.call_out.body', intervention_name: intervention.name)
  end

  def participant_handled_sms_content(intervention)
    I18n.t('navigator_mailer.participant_handled.body', intervention_name: intervention.name)
  end
end
