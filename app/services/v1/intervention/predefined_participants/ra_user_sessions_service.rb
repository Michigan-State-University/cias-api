# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::RaUserSessionsService
  def self.call(intervention, user_ids)
    new(intervention, user_ids).call
  end

  def initialize(intervention, user_ids)
    @intervention = intervention
    @user_ids = Array(user_ids)
  end

  def call
    return {} if user_ids.empty?

    ra_session = intervention.ra_session
    return {} if ra_session.nil?

    UserSession.where(session_id: ra_session.id, user_id: user_ids)
               .includes(:fulfilled_by)
               .index_by(&:user_id)
  end

  private

  attr_reader :intervention, :user_ids
end
