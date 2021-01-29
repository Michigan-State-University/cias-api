# frozen_string_literal: true

class V1::TeamsController < V1Controller
  def index
    render json: serialized_response(teams_scope)
  end

  def show
    render json: serialized_response(team)
  end

  def create
    team = Team.create(team_params)
    render json: serialized_response(team), status: :created
  end

  def update
    team.update(team_params)
    render json: serialized_response(team)
  end

  def destroy
    team.destroy
    head :no_content
  end

  private

  def teams_scope
    Team.all
  end

  def team
    Team.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name)
  end
end
