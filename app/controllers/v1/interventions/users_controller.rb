# frozen_string_literal: true

# Controller returns all users who have got grant access to all intervention associated with the problem;
# Check also Problem::StatusKeeper::Broadcast.
class V1::Interventions::UsersController < V1Controller
  def index
    render_json user_interventions: user_interventions_scope, action: :index_users_uniq
  end

  def create
    authorize! :create, UserIntervention

    problem_load.create_user_interventions(user_intervention_params[:emails])
    render_json user_interventions: user_interventions_scope, action: :index_users_uniq, status: :created
  end

  def destroy
    user_interventions_scope.where(user_id: params[:id], submitted_at: nil).destroy_all
    head :no_content
  end

  private

  def problem_load
    Problem.includes(:interventions, :user_interventions).accessible_by(current_ability).find(params[:problem_id])
  end

  def user_interventions_scope
    problem_load.user_interventions
  end

  def user_intervention_params
    params.require(:user_intervention).permit(emails: [])
  end
end
