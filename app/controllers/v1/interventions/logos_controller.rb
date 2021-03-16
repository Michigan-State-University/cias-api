# frozen_string_literal: true

class V1::Interventions::LogosController < V1Controller
  def create
    authorize_user
    chech_intervention_status

    intervention_load.update!(logo: intervention_params[:file])
    invalidate_cache(intervention_load)
    render json: serialized_response(intervention_load, 'Intervention'), status: :created
  end

  def destroy
    authorize_user
    chech_intervention_status

    intervention_load.logo.purge_later
    invalidate_cache(intervention_load)
    render json: serialized_response(intervention_load, 'Intervention')
  end

  private

  def authorize_user
    raise CanCan::AccessDenied unless current_v1_user.role?('admin')

    authorize! :update, intervention_load
  end

  def intervention_load
    Intervention.accessible_by(current_ability).find(params[:interventions_id])
  end

  def intervention_params
    params.require(:logo).permit(:file)
  end

  def chech_intervention_status
    raise CanCan::AccessDenied if intervention_load.status.eql? 'published'
  end
end
