# frozen_string_literal: true

class V1::SmsPlans::AlertPhones::PhonesController < V1Controller
  def create
    # this can even be empty, it will then be edited through update endpoint
    # also for alert phones they need to be confirmed by default
    phone = Phone.create!(phone_params.merge(confirmed: true))
    alert_load.phones << phone
    render json: serialized_response(phone, 'Phone'), status: :created
  end

  def destroy
    phone_load.destroy!
    head :no_content
  end

  def update
    phone = phone_load
    phone.update!(phone_params)
    render json: serialized_response(phone, 'Phone')
  end

  private

  def alert_params
    params.permit(:sms_plan_id, :id, phone: {})
  end

  def phone_params
    alert_params.require(:phone).permit(:iso, :prefix, :number)
  end

  def sms_alert_id
    alert_params[:sms_plan_id]
  end

  def alert_phone_id
    alert_params[:id]
  end

  def alert_load
    SmsPlan::Alert.accessible_by(current_ability).find(sms_alert_id)
  end

  def phone_load
    alert_load.alert_phones.find_by(phone_id: alert_phone_id).phone
  end
end
