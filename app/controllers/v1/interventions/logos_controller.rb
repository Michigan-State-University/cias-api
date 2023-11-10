# frozen_string_literal: true

class V1::Interventions::LogosController < V1Controller
  def create
    authorize! :add_logo, Intervention
    authorize! :add_logo, intervention_load
    return render status: :method_not_allowed if intervention_published?
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    intervention_load.update!(logo: intervention_params[:file])
    invalidate_cache(intervention_load)
    render json: serialized_response(intervention_load, 'Intervention'), status: :created
  end

  def update
    authorize! :add_logo, Intervention
    authorize! :add_logo, intervention_load
    return render status: :method_not_allowed if intervention_published?
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    intervention_load.logo_blob&.update!(description: intervention_params[:alt])
    render json: serialized_response(intervention_load, 'Intervention')
  end

  def destroy
    authorize! :add_logo, Intervention
    authorize! :add_logo, intervention_load
    return render status: :method_not_allowed if intervention_published?
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    intervention_load.logo.purge_later
    invalidate_cache(intervention_load)
    head :no_content
  end

  private

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:interventions_id])
  end

  def intervention_params
    params.require(:logo).permit(:file, :alt)
  end

  def intervention_published?
    intervention_load.published?
  end
end
