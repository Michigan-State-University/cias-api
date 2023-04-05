# frozen_string_literal: true

module FlowServiceHelper
  def next_user_session!(session)
    next_user_session = UserSession.find_or_initialize_by(session_id: session.id, user_id: user.id, health_clinic_id: health_clinic_id,
                                                          type: session.user_session_type, user_intervention: user_intervention)
    next_user_session.save!

    user_session.answers.confirmed.last.update!(next_session_id: session.id)
    next_user_session
  end

  delegate :session, to: :user_session

  def preview?
    user_session.session.intervention.draft?
  end

  def user
    @user ||= user_session.user
  end

  def health_clinic_id
    @health_clinic_id ||= user_session.health_clinic_id
  end

  def user_intervention
    @user_intervention = user_session.user_intervention
  end
end
