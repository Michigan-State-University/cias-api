# frozen_string_literal: true

class V1::SmsPlansController < V1Controller
  authorize_resource

  def index
    render json: serialized_response(sms_plans_scope)
  end

  def show
    render json: serialized_response(sms_plan)
  end

  def create
    authorize! :create, sms_plan_session

    return render status: :method_not_allowed if sms_plan_session.intervention.published?

    sms_plan = SmsPlan.create!(sms_plan_params)
    render json: serialized_response(sms_plan), status: :created
  end

  def update
    authorize! :update, sms_plan_session if sms_plan_params[:session_id].present?

    return render status: :method_not_allowed if intervention_published?

    sms_plan.update!(sms_plan_params)
    render json: serialized_response(sms_plan)
  end

  def destroy
    return render status: :method_not_allowed if intervention_published?

    sms_plan.destroy
    head :no_content
  end

  private

  def intervention_published?
    sms_plan.session.intervention.published?
  end

  def sms_plan_session
    Session.find(sms_plan_params[:session_id])
  end

  def sms_plans_scope
    SmsPlan.accessible_by(current_v1_user.ability)
  end

  def sms_plan
    @sms_plan ||= sms_plans_scope.find(params[:id])
  end

  def sms_plan_params
    params.require(:sms_plan).permit(
      :name, :schedule, :schedule_payload, :frequency, :session_id, :end_at, :formula, :no_formula_text,
      :is_used_formula
    )
  end
end
