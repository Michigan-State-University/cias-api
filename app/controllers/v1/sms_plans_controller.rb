# frozen_string_literal: true

class V1::SmsPlansController < V1Controller
  include Resource::Clone

  def index
    authorize! :read, SmsPlan

    collection = sms_plans_scope.detailed_search(params)

    render json: serialized_response(collection)
  end

  def show
    authorize! :read, sms_plan

    render json: V1::SmsPlanSerializer.new(sms_plan, { include: %i[variants phones sms_links] })
  end

  def create
    authorize! :create, SmsPlan
    authorize! :create, sms_plan_session

    return render status: :method_not_allowed if sms_plan_session.intervention.published?
    return head :forbidden unless sms_plan_session.ability_to_update_for?(current_v1_user)

    sms_plan = SmsPlan.create!(sms_plan_params)
    render json: serialized_response(sms_plan), status: :created
  end

  def update
    authorize! :update, sms_plan
    authorize! :update, sms_plan_session if sms_plan_params[:session_id].present?

    return render status: :method_not_allowed if intervention_published?
    return head :forbidden unless sms_plan.session.ability_to_update_for?(current_v1_user)

    sms_plan.update!(sms_plan_params)
    render json: serialized_response(sms_plan)
  end

  def destroy
    authorize! :destroy, sms_plan

    return render status: :method_not_allowed if intervention_published?
    return head :forbidden unless sms_plan.session.ability_to_update_for?(current_v1_user)

    sms_plan.destroy
    head :no_content
  end

  private

  def intervention_published?
    sms_plan.session.intervention.published?
  end

  def sms_plan_session
    @sms_plan_session ||= Session.find(sms_plan_params[:session_id])
  end

  def sms_plans_scope
    SmsPlan.accessible_by(current_v1_user.ability).includes(:variants, :phones, :sms_links)
  end

  def sms_plan
    @sms_plan ||= sms_plans_scope.find(params[:id])
  end

  def sms_plan_params
    params.require(:sms_plan).permit(
      :name, :schedule, :schedule_payload, :frequency, :session_id, :end_at, :formula, :no_formula_text,
      :is_used_formula, :type, :include_first_name, :include_last_name, :include_email,
      :include_phone_number, :no_formula_attachment, :schedule_variable, :sms_send_time_type, sms_send_time_details: {}
    )
  end
end
