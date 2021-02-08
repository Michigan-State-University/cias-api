# frozen_string_literal: true

class V1::Teams::InvitationsController < V1Controller
  def create
    authorize! :invite_researcher, team

    V1::Teams::InviteResearcher.call(
      team,
      params.require(:email)
    )

    render status: :created
  end

  private

  def team
    @team ||= Team.find(params[:team_id])
  end
end
