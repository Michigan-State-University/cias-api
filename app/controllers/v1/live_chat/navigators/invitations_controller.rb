# frozen_string_literal: true

class V1::LiveChat::Navigators::InvitationsController < V1Controller
  def index; end

  def create; end

  def destroy; end

  def confirm; end

  private

  def intervention_id
    params[:intervention_id]
  end

  def intervention_load
    Intervention.accessible_by(current_ability).find(intervention_id)
  end
end
