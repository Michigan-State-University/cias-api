# frozen_string_literal: true

class V1::LiveChat::Navigators::HelpingMaterialsController < V1Controller
  def show
    authorize! :read, LiveChat::Interventions::NavigatorSetup

    render json: V1::LiveChat::Interventions::HelpingMaterialsSerializer.new(setup_load, { include: %i[navigator_links] })
  end

  private

  def intervention_id
    params[:id]
  end

  def setup_load
    Intervention.find(intervention_id).navigator_setup
  end
end
