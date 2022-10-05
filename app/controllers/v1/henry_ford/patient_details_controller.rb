# frozen_string_literal: true

class V1::HenryFord::PatientDetailsController < V1Controller
  def create
    result = HfhsPatientDetail.find_or_create_by!(patient_params)
    render json: serialized_hash(result, HfhsPatientDetail)
  end

  def verify
    authorize! :read, UserSession

    result = V1::HenryFord::VerifyService.call(current_v1_user, patient_detail_params)
    render json: serialized_hash(result, HfhsPatientDetail)
  end

  private

  def patient_detail_params
    params.require(:hfhs_patient_data).permit(:mrn, :first_name, :last_name, :dob, :sex, :zip_code)
  end

  def hfhs_params
    params.permit(:patientID, :lastName, :firstName, :dob, :gender, :zip, :visitID).deep_transform_keys!(&:underscore)
  end
end
