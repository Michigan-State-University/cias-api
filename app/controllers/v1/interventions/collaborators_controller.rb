# frozen_string_literal: true

class V1::Interventions::CollaboratorsController < V1Controller
  def index
    authorize! :manage_collaborators, Intervention

    render json: serialized_response(collaborators_scope)
  end

  def create
    authorize! :manage_collaborators, Intervention

    new_collaborators = V1::Intervention::Collaborators::CreateService.call(intervention_load, emails)

    render json: serialized_response(new_collaborators), status: :created
  end

  def destroy
    authorize! :manage_collaborators, Intervention

    V1::Intervention::Collaborators::DestroyService.call(collaborator_load)

    head :no_content
  end

  def update
    authorize! :manage_collaborators, Intervention

    collaborator_load.update(collaborator_params)
    render json: serialized_response(collaborator_load)
  end

  private

  def intervention_load
    @intervention_load ||= if current_v1_user.role?('admin')
                             Intervention.accessible_by(current_ability).find(params[:intervention_id])
                           else
                             Intervention.accessible_by(current_ability).find_by!(id: params[:intervention_id], user_id: current_v1_user.id)
                           end
  end

  def collaborators_scope
    @collaborators_scope ||= intervention_load.collaborators
  end

  def collaborator_load
    @collaborator_load ||= collaborators_scope.find(collaborator_id)
  end

  def collaborator_params
    params.require(:collaborator).permit(:view, :edit, :data_access)
  end

  def emails
    params[:emails]
  end

  def collaborator_id
    params[:id]
  end
end
