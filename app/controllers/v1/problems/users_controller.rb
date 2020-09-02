# frozen_string_literal: true

class V1::Problems::UsersController < V1Controller
  def index
    render json: serialized_response(user_problems_scope, 'UserProblem')
  end

  def create
    authorize! :create, UserProblem

    user_problems = create_associations
    render json: serialized_response(user_problems, 'UserProblem'), status: :created
  end

  def destroy
    user_problem = user_problems_scope.find_by!(user_id: params[:id])
    user_problem.destroy!
    head :ok
  end

  private

  def user_problems_scope
    UserProblem.includes(:problem, :user).accessible_by(current_ability).where(problem_id: params[:problem_id])
  end

  def user_problem_params
    params.require(:user_problem).permit(emails: [])
  end

  def users_scope
    User.accessible_by(current_ability).limit_to_roles('participant').where(email: user_problem_params[:emails])
  end

  def problem_load
    Problem.accessible_by(current_ability).find(params[:problem_id])
  end

  def create_associations
    SqlQuery.new('user_problem/create', users: users_scope, problem_id: problem_load.id).execute if users_scope.any?
    user_problems_scope.where(user_id: users_scope.select(:id))
  end
end
