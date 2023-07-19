# frozen_string_literal: true

class V1::HenryFord::PatientDetailsController < V1Controller
  def verify
    authorize! :read, UserSession

    result = V1::HenryFord::VerifyService.call(current_v1_user, patient_detail_params, session_id)
    render json: serialized_hash(result, HfhsPatientDetail)
  end

  private

  def patient_detail_params
    params.require(:hfhs_patient_data).permit(:first_name, :last_name, :dob, :sex, :zip_code, :phone_number, :phone_type)
  end

  def session_id
    params[:session_id]
  end
end
