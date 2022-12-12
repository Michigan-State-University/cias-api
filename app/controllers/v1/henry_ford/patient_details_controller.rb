# frozen_string_literal: true

class V1::HenryFord::PatientDetailsController < V1Controller
  before_action :doorkeeper_authorize!, except: :verify
  before_action :authenticate_user!, except: [:create]

  def create
    result = HfhsPatientDetail.find_or_create_by!(
      patient_id: hfhs_params[:patient_id],
      first_name: hfhs_params[:first_name],
      last_name: hfhs_params[:last_name],
      dob: Date.parse(hfhs_params[:dob]),
      gender: hfhs_params[:gender],
      zip: hfhs_params[:zip]
    )
    result.update!(visit_id: hfhs_visit_id)
    head(:ok)
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
    @hfhs_params ||= params.permit(:patientID, :lastName, :firstName, :dob, :gender, :zip).deep_transform_keys!(&:underscore)
  end

  def hfhs_visit_id
    params[:visitID]
  end
end
