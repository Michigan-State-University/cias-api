# frozen_string_literal: true

class V1::Interventions::StarsController < V1Controller
  def create
    authorize! :read, Intervention

    current_v1_user.stars.find_or_create_by(intervention_id: intervention_load.id)

    clear_cache

    head :no_content
  end

  def destroy
    authorize! :read, Intervention

    current_v1_user.stars.delete_by(intervention_id: intervention_load.id)

    clear_cache

    head :no_content
  end

  private

  def interventions_scope
    @interventions_scope ||= Intervention.accessible_by(current_ability).only_visible
  end

  def intervention_load
    @intervention_load ||= interventions_scope.find(params[:intervention_id])
  end

  def clear_cache
    Rails.cache.delete_matched("intervention-serializer:#{current_v1_user.id}:intervention/#{intervention_load.id}-*")
    Rails.cache.delete_matched("simple-intervention-serializer:#{current_v1_user.id}:intervention/#{intervention_load.id}-*")
  end
end
