# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::SendSmsInvitation
  def initialize(user)
    @user = user
  end

  def self.call(user)
    new(user).call
  end

  def call
    return if user.phone.blank?
    raise ActiveRecord::ActiveRecordError, I18n.t('users.invite.predefined.not_active') unless user.active?

    sms = Message.create(phone: number, body: content)
    Communication::Sms.new(sms.id).send_message
    user.predefined_user_parameter.update!(sms_invitation_sent_at: DateTime.now)
  end

  attr_accessor :user

  private

  def number
    user.phone.full_number
  end

  def content
    I18n.with_locale(intervention_language_code) do
      I18n.t('predefined_participant.invitation', intervention_name: intervention_name, link: link)
    end
  end

  def link
    "#{ENV.fetch('WEB_URL', nil)}/usr/#{predefined_user_parameter.slug}"
  end

  def intervention_name
    predefined_user_parameter.intervention.name
  end

  def intervention_language_code
    predefined_user_parameter.intervention.language_code
  end

  def predefined_user_parameter
    @predefined_user_parameter ||= user.predefined_user_parameter
  end
end
