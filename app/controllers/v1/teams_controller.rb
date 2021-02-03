# frozen_string_literal: true

class V1::TeamsController < V1Controller
  authorize_resource only: %i[index show create update destroy]

  def index
    paginated_teams_scope = paginate(teams_scope, params)

    render json: V1::TeamSerializer.new(
      paginated_teams_scope,
      { meta: { teams_size: teams_scope.count }, include: [:team_admin] }
    )
  end

  def show
    render json: team_serialized_response(team)
  end

  def create
    new_team = V1::Teams::Create.call(team_params)
    render json: team_serialized_response(new_team), status: :created
  end

  def update
    updated_team = V1::Teams::Update.call(team, team_params)
    render json: team_serialized_response(updated_team)
  end

  def destroy
    V1::Teams::Destroy.call(team)
    head :no_content
  end

  private

  def team_serialized_response(team)
    V1::TeamSerializer.new(
      team,
      { include: [:team_admin] }
    )
  end

  def teams_scope
    Team.includes(team_admin: %i[phone avatar_attachment]).accessible_by(current_ability)
  end

  def team
    @team ||= teams_scope.find(params[:id])
  end

  def team_params
    params.require(:team).permit(:name, :user_id)
  end
end
