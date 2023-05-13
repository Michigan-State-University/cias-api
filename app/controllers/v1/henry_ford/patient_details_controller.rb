# frozen_string_literal: true

class V1::HenryFord::PatientDetailsController < V1Controller
  before_action :authenticate_user!

  def verify
    authorize! :read, UserSession

    result = V1::HenryFord::VerifyService.call(current_v1_user, patient_detail_params)
    render json: serialized_hash(result)
  end

  private

  def patient_detail_params
    params.require(:hfhs_patient_data).permit(:mrn, :first_name, :last_name, :dob, :sex, :zip_code)
  end
end
