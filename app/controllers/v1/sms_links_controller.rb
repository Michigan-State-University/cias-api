# frozen_string_literal: true

class V1::SmsLinksController < V1Controller
  skip_before_action :authenticate_user!, only: :verify

  def index
    authorize! :read, sms_link_sms_plan

    collection = sms_link_sms_plan.sms_links

    render json: serialized_response(collection)
  end

  def create
    authorize! :create, SmsLink
    authorize! :update, sms_link_session
    authorize! :update, sms_link_sms_plan

    return render status: :method_not_allowed if sms_link_session.intervention.published?
    return head :forbidden unless sms_link_session.ability_to_update_for?(current_v1_user)

    sms_link = SmsLink.create!(sms_link_params)
    render json: serialized_response(sms_link), status: :created
  end

  def verify
    render json: verify_response, status: :ok
  end

  private

  def sms_link_session
    @sms_link_session ||= sms_link_sms_plan.session
  end

  def sms_link_sms_plan
    @sms_link_sms_plan ||= SmsPlan.find(sms_link_params[:sms_plan_id])
  end

  def verify_response
    {
      link_type: sms_links_user&.sms_link&.link_type,
      redirect_url: V1::SmsLinks::VerifyService.call(sms_links_user)
    }
  end

  def sms_links_user
    @sms_links_user ||= SmsLinksUser.find_by(slug: params[:slug])
  end

  def sms_link_params
    params.require(:sms_link).permit(
      :url,
      :link_type,
      :variable,
      :sms_plan_id
    )
  end
end
