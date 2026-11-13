# frozen_string_literal: true

class PredefinedParticipants::SmsRecipientsQuery
  REMINDER_INTERVAL = 24.hours

  def self.call(campaign)
    new(campaign).call
  end

  def initialize(campaign)
    @campaign = campaign
  end

  def call
    case campaign.kind
    when 'invitation' then invitation_scope
    when 'manual_reminder' then manual_reminder_scope
    when 'scheduled_reminder' then scheduled_reminder_scope
    else raise ArgumentError, "Unsupported SMS campaign kind: #{campaign.kind.inspect}"
    end
  end

  private

  attr_reader :campaign

  def base_scope
    active = PredefinedUserParameter.joins(user: :phone).where(intervention_id: campaign.intervention_id, users: { active: true })
    V1::PredefinedParticipants::SmsDeliverability.deliverable(active).preload(user: :phone)
  end

  def completed
    UserIntervention.where(status: 'completed')
                    .where('user_interventions.user_id = predefined_user_parameters.user_id')
                    .where('user_interventions.intervention_id = predefined_user_parameters.intervention_id')
  end

  def invitation_scope
    base_scope.where(sms_invitation_sent_at: nil)
  end

  def manual_reminder_scope
    reminder_interval_elapsed(base_scope.where.not(sms_invitation_sent_at: nil).where.not(completed.arel.exists))
  end

  def scheduled_reminder_scope
    reminder_interval_elapsed(
      base_scope.where(first_opened_at: nil).where.not(sms_invitation_sent_at: nil).joins(parent_deliveries_join)
    )
  end

  def parent_deliveries_join
    PredefinedUserParameter.sanitize_sql_array(
      [
        'INNER JOIN predefined_participants_sms_deliveries parent_deliveries ' \
        'ON parent_deliveries.predefined_user_parameter_id = predefined_user_parameters.id ' \
        'AND parent_deliveries.campaign_id = ?',
        campaign.parent_campaign_id
      ]
    )
  end

  def reminder_interval_elapsed(scope)
    scope.where(
      'predefined_user_parameters.last_reminder_sent_at IS NULL OR predefined_user_parameters.last_reminder_sent_at <= ?',
      REMINDER_INTERVAL.ago
    )
  end
end
