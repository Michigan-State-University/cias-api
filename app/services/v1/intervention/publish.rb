# frozen_string_literal: true

class V1::Intervention::Publish
  def initialize(intervention)
    @intervention = intervention
    @sessions = intervention.sessions.order(:position)
  end

  def execute
    timestamp_published_at
    calculate_days_after_schedule
    delete_preview_data
    send_smses_to_predefined_users
  end

  private

  attr_accessor :intervention
  attr_reader :sessions

  def timestamp_published_at
    intervention.update!(published_at: Time.current)
  end

  def calculate_days_after_schedule
    schedule_time = DateTime.current
    sessions.each do |session|
      next if session.schedule == 'after_fill'

      if session.schedule == 'exact_date'
        schedule_time = session.schedule_at
        next
      end

      schedule_time += selected_number_of_days(session)
      next if %w[days_after_fill days_after_date].include?(session.schedule)

      if session.schedule == 'days_after'
        session.schedule_at = schedule_time.to_s
        session.save!
      end
    end
  end

  def delete_preview_data
    session_ids = intervention.sessions.select(:id)
    preview_users = User.where(preview_session_id: session_ids)
    preview_user_ids = preview_users.select(:id)
    UserIntervention.where(user_id: preview_user_ids).destroy_all
    UserLogRequest.where(user_id: preview_user_ids).destroy_all
    preview_users.destroy_all
  end

  def selected_number_of_days(session)
    return 0 if session.schedule_payload.blank?

    session.schedule_payload.days
  end

  def send_smses_to_predefined_users
    return unless predefined_user_parameters.any?

    predefined_user_parameters.each do |predefined_user_parameter|
      next unless predefined_user_parameter.auto_invitation

      V1::Intervention::PredefinedParticipants::SendInvitation.call(predefined_user_parameter.user)
    end
  end

  def predefined_user_parameters
    @predefined_user_parameters ||= intervention.predefined_user_parameters
  end
end
