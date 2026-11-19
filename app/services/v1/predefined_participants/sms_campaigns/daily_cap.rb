# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::DailyCap
  WINDOW = 24.hours
  EXCEEDED_CODE = 'DAILY_SMS_CAP_EXCEEDED'

  def self.enforce!(intervention, recipients_count)
    new(intervention).enforce!(recipients_count)
  end

  def initialize(intervention)
    @intervention = intervention
  end

  def enforce!(recipients_count)
    cap = Settings.sms_campaigns.daily_sms_cap
    return if cap.blank?
    return if committed_in_window + recipients_count <= cap

    raise ComplexException.new(
      I18n.t('predefined_participants.sms_campaigns.errors.daily_cap_exceeded'),
      { errors: [{ code: EXCEEDED_CODE }] },
      :unprocessable_content
    )
  end

  private

  attr_reader :intervention

  def committed_in_window
    ::PredefinedParticipants::SmsCampaign.where(intervention_id: cap_intervention_ids)
                                         .where.not(status: ::PredefinedParticipants::SmsCampaign::NOT_SENDING_STATUSES)
                                         .where(scheduled_at: WINDOW.ago..Time.current)
                                         .sum(:recipients_count)
  end

  def cap_intervention_ids
    return [intervention.id] if intervention.organization_id.blank?

    ::Intervention.where(organization_id: intervention.organization_id).select(:id)
  end
end
