# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorsController < V1Controller
  def index
    authorize! :read, Intervention

    render json: navigators_response(navigators_load)
  end

  def destroy
    authorize! :update, Intervention

    navigator = intervention_load.intervention_navigators.find_by!(user_id: intervention_navigator_id)
    navigator.destroy!

    head :no_content
  end

  private

  def intervention_id
    params[:id]
  end

  def intervention_navigator_id
    params[:navigator_id]
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
