# frozen_string_literal: true

class V1::Sessions::SmsPlansController < V1Controller
  def index
    authorize! :read, SmsPlan
    collection = session_load.sms_plans.detailed_search(params)

    render json: serialized_response(collection)
  end

  private

  def session_load
    Session.accessible_by(current_ability).find(params[:session_id])
  end
end
