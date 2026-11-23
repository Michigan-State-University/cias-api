# frozen_string_literal: true

# rubocop:disable Rails/SkipsModelValidations
class V1::PredefinedParticipants::ResendService
  SEND_FAILED_CODE = 'SMS_SEND_FAILED'
  ProviderError = Class.new(StandardError)

  TOO_SOON_CODE = 'RESEND_TOO_SOON'

  def self.call(user, intervention: nil, min_interval: nil)
    new(user, intervention, min_interval).call
  end

  def initialize(user, intervention, min_interval = nil)
    @user = user
    @scope_intervention = intervention
    @min_interval = min_interval
  end

  def call
    V1::PredefinedParticipants::AssertPublished.call(intervention)
    return if user.phone.blank?
    raise ActiveRecord::ActiveRecordError, I18n.t('users.invite.predefined.not_active') unless user.active?

    refuse_undeliverable

    delivery = latest_invitation_delivery
    claimed = claim_interval
    deliver_or_release(delivery, claimed)
    record(delivery)
  end

  private

  attr_reader :user, :scope_intervention, :min_interval

  def claim_interval
    return unless min_interval

    rows = PredefinedUserParameter.where(id: parameter.id)
    now = Time.current
    claimed = rows.where('last_resent_at IS NULL OR last_resent_at <= ?', now - min_interval).update_all(last_resent_at: now)
    return { rows: rows, previous: parameter.last_resent_at, at: now } if claimed.positive?

    raise_too_soon(rows)
  end

  def raise_too_soon(rows)
    last = rows.pick(:last_resent_at) || Time.current
    retry_after = [(last + min_interval - Time.current).ceil, 1].max
    raise ComplexException.new(I18n.t('predefined_participants.resend.errors.too_soon'),
                               { errors: [{ code: TOO_SOON_CODE }], retry_after: retry_after }, :too_many_requests)
  end

  def deliver_or_release(delivery, claimed)
    deliver(delivery&.body || locale_body)
  rescue StandardError
    release_interval(claimed)
    raise
  end

  def release_interval(claimed)
    return unless claimed

    claimed[:rows].where(last_resent_at: claimed[:at]).update_all(last_resent_at: claimed[:previous])
  end

  def parameter
    @parameter ||=
      if scope_intervention
        PredefinedUserParameter.find_by!(user_id: user.id, intervention_id: scope_intervention.id)
      else
        user.predefined_user_parameter
      end
  end

  def intervention
    @intervention ||= scope_intervention || parameter.intervention
  end

  def latest_invitation_delivery
    ::PredefinedParticipants::SmsDelivery.joins(:campaign)
                                         .where(predefined_user_parameter_id: parameter.id, campaign: { kind: 'invitation' })
                                         .order(created_at: :desc, id: :desc).first
  end

  def locale_body
    V1::Intervention::PredefinedParticipants::SendSmsInvitation.new(user).content
  end

  def refuse_undeliverable
    code = ::V1::PredefinedParticipants::SmsDeliverability.refusal(user)
    return unless code

    raise ComplexException.new(I18n.t("predefined_participants.resend.errors.#{code.downcase}"),
                               { errors: [{ code: code }] }, :unprocessable_content)
  end

  def deliver(body)
    code = V1::PredefinedParticipants::DeliverSms.call(user.phone.full_number, body).error_code
    return unless code

    report(code)
    raise ComplexException.new(I18n.t('predefined_participants.resend.errors.send_failed'),
                               { errors: [{ code: SEND_FAILED_CODE }] }, :unprocessable_content)
  end

  def report(code)
    Rails.logger.warn("[#{self.class.name}] provider failure: user_id=#{user.id} error=#{code}")
    V1::PredefinedParticipants::ReportSmsError.call(ProviderError, code, extra: { intervention_id: intervention.id })
  end

  def record(delivery)
    now = Time.current
    ApplicationRecord.transaction do
      ::PredefinedParticipants::SmsDelivery.update_counters(delivery.id, resend_count: 1, touch: :last_resent_at) if delivery
      PredefinedUserParameter.where(id: parameter.id, sms_invitation_sent_at: nil)
                             .update_all(sms_invitation_sent_at: now, updated_at: now)
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
