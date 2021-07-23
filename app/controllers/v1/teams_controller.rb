# frozen_string_literal: true

class V1::TeamsController < V1Controller
  def index
    authorize! :index, Team

    paginated_teams_scope = paginate(teams_scope, params)

    render json: V1::TeamSerializer.new(
      paginated_teams_scope,
      { meta: { teams_size: teams_scope.count }, include: [:team_admin] }
    )
  end

  def show
    authorize! :show, Team

    render json: team_serialized_response(team)
  end

  def create
    authorize! :create, Team

    new_team = V1::Teams::Create.call(team_params)
    render json: team_serialized_response(new_team), status: :created
  end

  def update
    authorize! :update, Team

    updated_team = V1::Teams::Update.call(team, team_params, current_ability)
    render json: team_serialized_response(updated_team)
  end

  def destroy
    authorize! :destroy, Team

    V1::Teams::Destroy.call(team)
    head :no_content
  end

  def remove_researcher
    authorize! :remove_researcher, Team

    team.users.researchers.find(params.require(:user_id)).update!(team_id: nil)

    render status: :ok
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
    @team ||= teams_scope.find(params[:id] || params[:team_id])
  end

  def team_params
    params.require(:team).permit(:name, :user_id)
  end
end
