# frozen_string_literal: true

class V1::SmsPlans::Variants::AttachmentsController < V1Controller
  def delete
    authorize! :update, variant

    return render status: :method_not_allowed if intervention_published?

    variant.attachment.purge_later
    invalidate_cache(variant)
    head :no_content
  end

  private

  def variant
    @variant ||= variant_scope.find(params[:id])
  end

  def variant_scope
    SmsPlan::Variant.accessible_by(current_ability)
  end

  def sms_plan
    @sms_plan ||= SmsPlan.accessible_by(current_ability).find(params[:sms_plan_id])
  end

  def intervention_published?
    sms_plan.session.intervention.published?
  end
end
