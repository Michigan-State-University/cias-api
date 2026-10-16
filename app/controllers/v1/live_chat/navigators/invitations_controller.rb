# frozen_string_literal: true

class V1::LiveChat::Navigators::InvitationsController < V1Controller
  include MessageHandler

  skip_before_action :authenticate_user!, only: %i[confirm]

  def index
    authorize! :read, Intervention
    authorize! :read, intervention_load

    render json: serialized_response(not_accepted_invitations, 'LiveChat::Interventions::NavigatorInvitation')
  end

  def create
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    created_invitations = V1::LiveChat::InviteNavigators.call(
      navigator_invitation_params[:emails].map(&:downcase),
      Intervention.find(intervention_id)
    )

    render json: serialized_response(created_invitations, 'LiveChat::Interventions::NavigatorInvitation'), status: :created
  end

  def destroy
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    not_accepted_invitations.find(invitation_id).destroy
    render status: :ok
  end

  def confirm
    intervention = Intervention.find(intervention_id)
    invitation = intervention.live_chat_navigator_invitations.not_accepted.find_by(email: email, intervention_id: intervention.id)
    if invitation.nil?
      redirect_to_web_app(error: I18n.t('live_chat.navigators.invitations.error'))
      return
    end
    intervention.navigators << User.find_by(email: email)
    invitation.update!(accepted_at: DateTime.now)
    broadcast_massage(intervention)

    redirect_to_web_app(success: I18n.t('live_chat.navigators.invitations.success', intervention_name: intervention.name))
  end

  private

  def navigator_invitation_params
    params.expect(navigator_invitation: [:intervention_id, { emails: [] }])
  end

  def email
    params[:email]
  end

  def intervention_id
    params[:intervention_id]
  end

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(intervention_id)
  end

  def invitation_id
    params[:id]
  end

  def not_accepted_invitations
    intervention_load.live_chat_navigator_invitations.not_accepted
  end

  def broadcast_massage(intervention)
    return if intervention.navigators_count != 1

    channel = "navigators_in_intervention_channel_#{intervention.id}"

    ActionCable.server.broadcast(channel, generic_message('', 'intervention_has_navigators'))
  end
end
