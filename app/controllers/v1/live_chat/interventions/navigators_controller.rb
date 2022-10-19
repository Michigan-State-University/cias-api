# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorsController < V1Controller
  def index
    authorize! :read, Intervention

    render json: navigators_response(navigators_load)
  end

  def create
    authorize! :update, Intervention

    added_navigator = V1::LiveChat::Interventions::Navigators::Assign.call(navigator_id, intervention_load)
    render json: navigators_response(added_navigator)
  end

  def destroy
    authorize! :update, Intervention

    navigator = intervention_load.intervention_navigators.find_by!(user_id: intervention_navigator_id)
    ActiveRecord::Base.transaction do
      LiveChat::Conversation.navigator_conversations(navigator.user).update_all(archived: true) # rubocop:disable Rails/SkipsModelValidations
      navigator.destroy!
    end

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

  def navigator_id
    params['navigator_id']
  end
end
