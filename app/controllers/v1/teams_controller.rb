# frozen_string_literal: true

class V1::TeamsController < V1Controller
  authorize_resource only: %i[index show create update destroy]

  def index
    render json: serialized_response(teams_scope)
  end

  def show
    render json: serialized_response(team)
  end

  def create
    new_team = V1::Teams::Create.call(team_params)
    render json: serialized_response(new_team), status: :created
  end

  def update
    team.update(team_params)
    render json: serialized_response(team)
  end

  def destroy
    team.destroy
    head :no_content
  end

  def add_team_admin
    authorize! :add_team_admin, Team

    V1::Teams::AddTeamAdmin.call(
      team,
      params.require(:user_id)
    )

    render json: serialized_response(team)
  end

  private

  def teams_scope
    Team.includes(:team_admin).accessible_by(current_ability)
  end

  def team
    @team ||= teams_scope.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :user_id)
  end
end
