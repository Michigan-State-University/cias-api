# frozen_string_literal: true

# Controller returns all users who have got grant access to all session associated with the problem;
# Check also Problem::StatusKeeper::Broadcast.
class V1::Sessions::UsersController < V1Controller
  def index
    render_json user_sessions: user_sessions_scope, action: :index_users_uniq
  end

  def create
    authorize! :create, UserSession

    problem_load.create_user_sessions(user_session_params[:emails])
    render_json user_sessions: user_sessions_scope, action: :index_users_uniq, status: :created
  end

  def destroy
    user_sessions_scope.where(user_id: params[:id], submitted_at: nil).destroy_all
    head :no_content
  end

  private

  def problem_load
    Problem.includes(:sessions, :user_sessions).accessible_by(current_ability).find(params[:problem_id])
  end

  def user_sessions_scope
    problem_load.user_sessions
  end

  def user_session_params
    params.require(:user_session).permit(emails: [])
  end
end
