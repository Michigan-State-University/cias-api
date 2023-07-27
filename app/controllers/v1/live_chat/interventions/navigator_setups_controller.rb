# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorSetupsController < V1Controller
  def show
    authorize! :read, Intervention
    authorize! :read, intervention_load

    render json: setup_response(navigator_setup_load)
  end

  def update
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    setup = navigator_setup_load
    V1::LiveChat::Interventions::UpdateNavigatorSetupService.call(setup, navigator_setup_params)
    render json: setup_response(setup)
  end

  private

  def intervention_id
    params[:id]
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_v1_user.ability).find(intervention_id)
  end

  def navigator_setup_load
    intervention_load.navigator_setup
  end

  def setup_response(data)
    V1::LiveChat::Interventions::NavigatorSetupSerializer.new(data, { include: %i[participant_links navigator_links phone message_phone] })
  end

  def navigator_setup_params
    params.require(:navigator_setup).permit(:contact_email, :no_navigator_available_message,
                                            :filled_script_template, :contact_message, phone_attributes: %i[iso number prefix],
                                                                                       message_phone_attributes: %i[iso number prefix])
  end
end
