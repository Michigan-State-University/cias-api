# frozen_string_literal: true

class V1::SmsPlans::VariantsController < V1Controller
  def create
    authorize! :create, SmsPlan::Variant
    return render status: :method_not_allowed if sms_plan.session.intervention.published?

    variant = sms_plan.variants.create!(variant_params)
    render json: variant_serialized_response(variant), status: :created
  end

  def update
    authorize! :update, variant
    return render status: :method_not_allowed if intervention_published?

    variant.update!(variant_params)
    render json: variant_serialized_response(variant)
  end

  def destroy
    authorize! :destroy, variant
    return render status: :method_not_allowed if intervention_published?

    variant.destroy
    head :no_content
  end

  private

  def intervention_published?
    sms_plan.session.intervention.published?
  end

  def variant_serialized_response(variant)
    serialized_response(variant, 'SmsPlan::Variant')
  end

  def sms_plan
    @sms_plan ||= SmsPlan.accessible_by(current_ability).find(params[:sms_plan_id])
  end

  def variant
    @variant ||= variant_scope.find(params[:id])
  end

  def variant_scope
    SmsPlan::Variant.accessible_by(current_ability)
  end

  def variant_params
    params.require(:variant).permit(:formula_match, :content)
  end
end
