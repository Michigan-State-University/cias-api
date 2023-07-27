# frozen_string_literal: true

class V1::UserSessions::FetchService < V1::UserSessions::BaseService
  def call
    @user_intervention = UserIntervention.find_by!(
      user_id: user_id,
      intervention_id: intervention_id,
      health_clinic_id: health_clinic_id
    )

    raise CanCan::AccessDenied, I18n.t('user_sessions.errors.scheduled_session') if user_session&.scheduled_at&.future?

    user_session
  end

  private

  def user_session
    @user_session ||= if user_intervention.contain_multiple_fill_session
                        unfinished_session
                      else
                        find_user_session(:find_by!)
                      end

    @user_session.update!(started: true)
    @user_session
  end
end
