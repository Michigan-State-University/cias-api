# frozen_string_literal: true

class V1::Tlfb::DaysController < V1Controller
  def index
    authorize! :read, UserIntervention

    render json: day_response(load_days)
  end

  private

  def user_session_id
    params[:user_session_id]
  end

  def tlfb_group_id
    params[:tlfb_group_id]
  end

  def load_days
    Tlfb::Day.accessible_by(current_ability).where(user_session_id: user_session_id, question_group_id: tlfb_group_id)
  end

  def day_response(days)
    V1::Tlfb::DaySerializer.new(
      days,
      { include: %i[events consumption_result] }
    )
  end
end
