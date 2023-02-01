# frozen_string_literal: true

class V1::LiveChat::Navigators::TabsController < V1Controller
  def show
    authorize! :read, Intervention

    render json: V1::LiveChat::Interventions::NavigatorTabSerializer.new(intervention_load)
  end

  private

  def intervention_id
    params[:id]
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_v1_user.ability).find(intervention_id)
  end
end
