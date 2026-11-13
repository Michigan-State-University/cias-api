# frozen_string_literal: true

class V1::PredefinedParticipants::AssertPublished
  REASONS = {
    'draft' => 'INTERVENTION_DRAFT',
    'paused' => 'INTERVENTION_PAUSED',
    'closed' => 'INTERVENTION_CLOSED',
    'archived' => 'INTERVENTION_CLOSED'
  }.freeze

  def self.call(intervention)
    return if intervention.published?

    raise ComplexException.new(
      I18n.t('predefined_participants.sms_campaigns.errors.intervention_not_published'),
      { reason: REASONS.fetch(intervention.status, 'INTERVENTION_CLOSED') },
      :bad_request
    )
  end
end
