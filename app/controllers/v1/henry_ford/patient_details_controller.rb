# frozen_string_literal: true

class V1::HenryFord::PatientDetailsController < V1Controller
  def verify
    authorize! :read, UserSession

    result = V1::HenryFord::VerifyService.call(current_v1_user, patient_detail_params, session_id)
    render json: serialized_hash(result, HfhsPatientDetail)
  end

  def verify_by_code
    authorize! :read, UserSession

    result = V1::HenryFord::HandleBarCodeService.call(verify_code_params)

    render json: serialized_hash(result, HfhsPatientDetail)
  end

  private

  def patient_detail_params
    params.require(:hfhs_patient_data).permit(:first_name, :last_name, :dob, :sex, :zip_code, :phone_number, :phone_type, :mrn)
  end

  def verify_code_params
    params.require(:hfhs_patient_data).permit(:barcode)
  end

  def session_id
    params[:session_id]
  end
end
