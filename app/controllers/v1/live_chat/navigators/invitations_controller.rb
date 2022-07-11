# frozen_string_literal: true

class V1::LiveChat::Navigators::InvitationsController < V1Controller
  skip_before_action :authenticate_user!, only: %i[confirm]

  def index; end

  def create; end

  def destroy; end

  def confirm
    intervention = intervention_load
    intervention.navigators << User.find_by(email: email)
    intervention.live_chat_navigator_invitations.find_by!(email: email, intervention_id: intervention.id).update!(accepted_at: DateTime.now)

    redirect_to_web_app(success: I18n.t('live_chat.navigators.invitations.success', intervention_name: intervention.name))
  end

  private

  def email
    params[:email]
  end

  def intervention_id
    params[:intervention_id]
  end

  def intervention_load
    Intervention.find(intervention_id)
  end

  def redirect_to_web_app(**message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV['WEB_URL']}?#{message.to_query}"
  end
end
