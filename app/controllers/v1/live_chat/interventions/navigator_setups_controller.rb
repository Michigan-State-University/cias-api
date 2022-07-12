# frozen_string_literal: true

class V1::LiveChat::Interventions::NavigatorSetupsController < V1Controller
  def show
    authorize! :read, Intervention

    render json: setup_response(navigator_setup_load)
  end

  def update
    authorize! :update, Intervention

    setup = navigator_setup_load
    update_setup(setup)
    render json: setup_response(setup)
  end

  private

  def intervention_id
    params[:id]
  end

  def intervention_load
    Intervention.accessible_by(current_v1_user.ability).find(intervention_id)
  end

  def navigator_setup_load
    intervention_load.navigator_setup
  end

  def setup_response(data)
    V1::LiveChat::Interventions::NavigatorSetupSerializer.new(data, { include: %i[participant_links phone] })
  end

  def navigator_setup_params
    params.require(:navigator_setup).permit(:contact_email, :notify_by, :no_navigator_available_message, :is_navigator_notification_on,
                                            phone: %i[iso number prefix])
  end

  def update_setup(setup)
    if setup.phone.nil?
      setup.update!(navigator_setup_params.merge({ phone: new_phone }))
    else
      setup.update!(navigator_setup_params.except(:phone))
      setup.phone.update(navigator_setup_params[:phone])
    end
  end

  def new_phone
    Phone.create!(navigator_setup_params[:phone]) if navigator_setup_params[:phone].present?
  end
end
