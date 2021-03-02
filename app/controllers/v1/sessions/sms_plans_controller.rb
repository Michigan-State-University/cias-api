# frozen_string_literal: true

class V1::Sessions::SmsPlansController < V1Controller
  def index
    authorize! :read, SmsPlan

    render json: serialized_response(session_load.sms_plans)
  end

  private

  def session_load
    Session.accessible_by(current_ability).find(params[:session_id])
  end
end
