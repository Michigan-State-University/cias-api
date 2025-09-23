# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorsController < V1Controller
  include MessageHandler

  def index
    authorize! :read, Intervention

    render json: navigators_response(navigators_load)
  end

  def create
    authorize! :update, Intervention
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    added_navigator = V1::LiveChat::Interventions::Navigators::Assign.call(navigator_id, intervention_load)
    render json: navigators_response(added_navigator)
  end

  def destroy
    authorize! :update, Intervention
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    navigator = intervention_load.intervention_navigators.find_by!(user_id: intervention_navigator_id)
    ActiveRecord::Base.transaction do
      LiveChat::Conversation.navigator_conversations(navigator.user).update_all(archived_at: DateTime.now) # rubocop:disable Rails/SkipsModelValidations
      navigator.destroy!
      broadcast_massage(intervention_load)
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

  def broadcast_massage(intervention)
    return unless intervention.navigators_count.zero?

    channel = "navigators_in_intervention_channel_#{intervention.id}"

    ActionCable.server.broadcast(channel, generic_message('', 'intervention_has_no_navigators'))
  end
end
