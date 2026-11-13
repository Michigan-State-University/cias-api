# frozen_string_literal: true

class V1::PredefinedParticipants::SmsDeliverability
  OPTED_OUT = 'SMS_OPTED_OUT'
  NOT_ELIGIBLE = 'SMS_NOT_ELIGIBLE'

  def self.refusal(user, opted_out_user_ids: nil)
    opted_out = opted_out_user_ids ? opted_out_user_ids.include?(user.id) : ::SmsOptOut.exists?(user_id: user.id)
    return OPTED_OUT if opted_out

    NOT_ELIGIBLE unless user.phone&.sms_eligible?
  end

  def self.deliverable(parameters)
    opted_out = ::SmsOptOut.where('sms_opt_outs.user_id = predefined_user_parameters.user_id')
    parameters.where(phones: { sms_eligible: true }).where.not(opted_out.arel.exists)
  end
end
