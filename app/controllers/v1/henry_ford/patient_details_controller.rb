# frozen_string_literal: true

class V1::HenryFord::PatientDetailsController < V1Controller
  def verify
    authorize! :read, UserSession

    result = V1::HenryFord::VerifyService.call(current_v1_user, patient_detail_params, session_id)
    render json: serialized_hash(result, HfhsPatientDetail)
  end

  def verify_by_code
    authorize! :read, UserSession
    authorize_hfhs_scan_session!

    result = V1::HenryFord::HandleBarCodeService.call(current_v1_user, verify_code_params)

    render json: serialized_hash(result, 'HfhsPatientDetailAnonymized')
  end

  private

  def patient_detail_params
    params.require(:hfhs_patient_data).permit(:id, :first_name, :last_name, :dob, :sex, :zip_code, :phone_number, :phone_type, :mrn)
  end

  def verify_code_params
    params.require(:hfhs_patient_data).permit(:barcode)
  end

  def session_id
    params[:session_id]
  end

  def authorize_hfhs_scan_session!
    session = Session.find_by(id: params.require(:session_id))

    return if session&.intervention&.hfhs_access? &&
              session.questions.exists?(type: 'Question::HenryFordInitial') &&
              session.user_sessions.exists?(user_id: current_v1_user.id)

    raise CanCan::AccessDenied, I18n.t('henry_ford.error.session.not_allowed')
  end
end
