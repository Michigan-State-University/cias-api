# frozen_string_literal: true

class V1::LiveChat::Intervention::ParticipantLinksController < V1Controller
  def update
    authorize! :update, Intervention

    link = participant_link_load
    link.update!(participant_link_params)
    head :ok
  end

  def create
    authorize! :create, Intervention

    navigator_setup = setup_load
    LiveChat::Intervention::ParticipantLink.create!(participant_link_params.merge(navigator_setup_id: navigator_setup.id))
    render json: V1::LiveChat::Intervention::NavigatorSetupSerializer.new(navigator_setup), status: :created
  end

  private

  def participant_link_params
    params.require(:participant_link).permit(:url, :display_name)
  end

  def participant_link_load
    setup_load.participant_links.find(link_id)
  end

  def link_id
    params[:participant_link_id]
  end

  def intervention_id
    params[:id]
  end

  def setup_load
    Intervention.accessible_by(current_v1_user.ability).find(intervention_id).navigator_setup
  end
end
