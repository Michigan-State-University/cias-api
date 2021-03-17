# frozen_string_literal: true

class V1::Interventions::LogosController < V1Controller
  def create
    authorize_user
    return render status: :method_not_allowed if intervention_published?

    intervention_load.update!(logo: intervention_params[:file])
    invalidate_cache(intervention_load)
    render json: serialized_response(intervention_load, 'Intervention'), status: :created
  end

  def destroy
    authorize_user
    return render status: :method_not_allowed if intervention_published?

    intervention_load.logo.purge_later
    invalidate_cache(intervention_load)
    head :no_content
  end

  private

  def authorize_user
    authorize! :add_logo, Intervention
  end

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:interventions_id])
  end

  def intervention_params
    params.require(:image).permit(:file)
  end

  def intervention_published?
    intervention_load.published?
  end
end
