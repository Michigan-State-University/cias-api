# frozen_string_literal: true

class V1::Interventions::TagsController < V1Controller
  def assign
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    added_tags = V1::Intervention::AssignTags.call(intervention_load, tag_ids, tag_names)

    render json: serialized_hash(added_tags).to_json, status: :created
  end

  def destroy
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    TagIntervention.find_by(tag_id: params[:id], intervention_id: intervention_load.id)&.destroy

    head :no_content
  end

  private

  def interventions_scope
    @interventions_scope ||= Intervention.accessible_by(current_ability).only_visible
  end

  def intervention_load
    @intervention_load ||= interventions_scope.find(params[:intervention_id])
  end

  def intervention_tags_assign_params
    params.expect(tag: [tag_ids: [], names: []])
  end

  def tag_ids
    intervention_tags_assign_params[:tag_ids]
  end

  def tag_names
    intervention_tags_assign_params[:names]
  end
end
