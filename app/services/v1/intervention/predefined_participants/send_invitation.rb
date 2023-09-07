# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::SendInvitation
  def initialize(user)
    @user = user
  end

  def self.call(user)
    new(user).call
  end

  def call
    return if user.phone.blank?

    sms = Message.create(phone: number, body: content)
    Communication::Sms.new(sms.id).send_message
    user.predefined_user_parameter.update!(invitation_sent_at: DateTime.now)
  end

  attr_accessor :user

  private

  def number
    user.phone.full_number
  end

  def content
    I18n.t('predefined_participant.invitation', intervention_name: intervention_name, link: link)
  end

  def link
    "#{ENV['WEB_URL']}/usr/#{predefined_user_parameter.slug}"
  end

  def intervention_name
    predefined_user_parameter.intervention.name
  end

  def predefined_user_parameter
    @predefined_user_parameter ||= user.predefined_user_parameter
  end
end
