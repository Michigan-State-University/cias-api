# frozen_string_literal: true

class V1::SmsPlans::NoFormulaAttachmentsController < V1Controller
  def delete
    authorize! :update, sms_plan
    return render status: :method_not_allowed if intervention_published?

    sms_plan.no_formula_attachment.purge_later
    invalidate_cache(sms_plan)
    head :no_content
  end

  private

  def sms_plans_scope
    SmsPlan.accessible_by(current_v1_user.ability)
  end

  def sms_plan
    @sms_plan ||= sms_plans_scope.find(params[:sms_plan_id])
  end

  def intervention_published?
    sms_plan.session.intervention.published?
  end
end
