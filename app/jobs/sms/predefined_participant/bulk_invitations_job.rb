# frozen_string_literal: true

class Sms::PredefinedParticipant::BulkInvitationsJob < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    predefined_user_parameters = intervention.predefined_user_parameters.any?
    return unless predefined_user_parameters.any?

    predefined_user_parameters.each do |predefined_user_parameter|
      next unless predefined_user_parameters.auto_invitation

      V1::Intervention::PredefinedParticipants::SendInvitation.call(predefined_user_parameter.user)
      predefined_user_parameter.update!(invitation_sent_at: DateTime.now)
    end
  end
end
