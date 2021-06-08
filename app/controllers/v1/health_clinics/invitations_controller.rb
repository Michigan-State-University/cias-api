# frozen_string_literal: true

class V1::HealthClinics::InvitationsController < V1Controller
  before_action :authenticate_user!, except: [:confirm]

  def invite_health_clinic_admin
    authorize! :invite_health_clinic_admin, HealthClinic

    V1::HealthClinics::InviteHealthClinicAdmin.call(
      health_clinic,
      params.require(:email)
    )

    render status: :created
  end

  def confirm
    V1::HealthClinics::Invitations::Confirm.call(health_clinic_invitation)

    redirect_to_web_app(
      success: I18n.t('organizables.invitations.accepted', organizable_type: 'Health Clinic', organizable_name: health_clinic_invitation.health_clinic.name)
    )
  rescue ActiveRecord::RecordNotFound
    redirect_to_web_app(
      error: I18n.t('organizables.invitations.not_found', organizable_type: 'Health Clinic')
    )
  end

  private

  def health_clinic_invitation
    @health_clinic_invitation ||= HealthClinicInvitation.not_accepted.
        find_by!(invitation_token: params.require(:invitation_token))
  end

  def redirect_to_web_app(**message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV['WEB_URL']}?#{message.to_query}"
  end

  def health_clinic
    @health_clinic ||= HealthClinic.accessible_by(current_ability).find(params[:health_clinic_id])
  end
end
