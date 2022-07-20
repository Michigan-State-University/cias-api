# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorsController < V1Controller
  def index
    authorize! :read, Intervention

    render json: navigators_response(navigators_load)
  end

  private

  def intervention_id
    params[:id]
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_v1_user.ability).find(intervention_id)
  end

  def navigators_load
    intervention_load.navigators
  end

  def navigators_response(data)
    V1::LiveChat::Interventions::NavigatorSerializer.new(data)
  end
end
