# frozen_string_literal: true

class V1::LiveChat::Interventions::LinksController < V1Controller
  def create
    authorize! :update, Intervention
    authorize! :create, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    navigator_setup = setup_load
    LiveChat::Interventions::Link.create!(link_params.merge(navigator_setup_id: navigator_setup.id))
    render json: V1::LiveChat::Interventions::NavigatorSetupSerializer.new(navigator_setup, { include: %i[participant_links navigator_links phone] }),
           status: :created
  end

  def update
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    link = link_load
    link.update!(link_params)
    head :ok
  end

  def destroy
    authorize! :delete, LiveChat::Interventions::Link
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    link_load&.destroy
    head :ok
  end

  private

  def link_params
    params.require(:link).permit(:url, :display_name, :link_for)
  end

  def link_load
    setup_load.navigator_links.find_by(id: link_id) || setup_load.participant_links.find_by(id: link_id)
  end

  def link_id
    params[:link_id]
  end

  def intervention_id
    params[:id]
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_v1_user.ability).find(intervention_id)
  end

  def setup_load
    intervention_load.navigator_setup
  end
end
