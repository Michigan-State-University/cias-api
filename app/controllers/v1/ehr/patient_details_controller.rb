# frozen_string_literal: true

class V1::Ehr::PatientDetailsController < V1Controller
  # `with:` keeps a plain 429; the Rails 8.1 default raises TooManyRequests.
  rate_limit to: 5, within: 10.minutes, by: -> { current_v1_user.id },
             with: -> { head :too_many_requests }, only: :verify_by_code

  def verify
    authorize! :read, UserSession

    result = V1::Ehr::VerifyService.call(current_v1_user, patient_detail_params, session_id)
    render json: serialized_hash(result, HfhsPatientDetail)
  end

  def verify_by_code
    authorize! :read, UserSession
    authorize_hfhs_scan_session!

    result = V1::Ehr::HandleBarCodeService.call(current_v1_user, verify_code_params)

    render json: serialized_hash(result, 'HfhsPatientDetailAnonymized')
  end

  private

  def patient_detail_params
    params.expect(hfhs_patient_data: %i[id first_name last_name dob sex zip_code phone_number phone_type mrn])
  end

  def verify_code_params
    params.expect(hfhs_patient_data: %i[barcode])
  end

  def session_id
    params[:session_id]
  end

  def authorize_hfhs_scan_session!
    return if Ehr::Settings.barcode_scan_available? && scan_allowed_in?(Session.find_by(id: params.require(:session_id)))

    raise CanCan::AccessDenied, I18n.t('henry_ford.error.session.not_allowed')
  end

  def scan_allowed_in?(session)
    session&.intervention&.hfhs_access? &&
      session.questions.exists?(type: 'Question::HenryFordInitial') &&
      session.user_sessions.exists?(user_id: current_v1_user.id)
  end
end
