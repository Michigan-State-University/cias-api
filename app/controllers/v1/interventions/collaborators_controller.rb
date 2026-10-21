# frozen_string_literal: true

class V1::Interventions::CollaboratorsController < V1Controller
  def index
    authorize! :manage_collaborators, Intervention

    render json: serialized_response(collaborators_scope)
  end

  def show
    authorize! :read, Intervention

    render json: serialized_response(collaborators_scope.find_by!(user_id: current_v1_user.id), controller_name.classify, params: { skip_user_data: true })
  end

  def create
    authorize! :manage_collaborators, Intervention

    new_collaborators = V1::Intervention::Collaborators::CreateService.call(intervention_load, emails)

    render json: serialized_response(new_collaborators), status: :created
  end

  def update
    authorize! :manage_collaborators, Intervention
    block_admin_to_give_data_access!

    collaborator_load.update(collaborator_params)
    render json: serialized_response(collaborator_load)
  end

  def destroy
    authorize! :manage_collaborators, Intervention

    V1::Intervention::Collaborators::DestroyService.call(collaborator_load)

    head :no_content
  end

  private

  def intervention_load
    @intervention_load ||= if current_v1_user.role?('admin') || action_name.eql?('show')
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
    params.expect(collaborator: %i[view edit data_access])
  end

  def emails
    params[:emails]
  end

  def collaborator_id
    params[:id]
  end

  def block_admin_to_give_data_access!
    return if current_v1_user.id == intervention_load.user_id
    return unless collaborator_params.key?(:data_access)

    raise ActiveModel::ForbiddenAttributesError, I18n.t('activerecord.errors.models.intervention.attributes.collaborators.data_access')
  end
end
