# frozen_string_literal: true

class V1::ProblemsController < V1Controller
  include Resource::Clone
  skip_before_action :authenticate_v1_user!, on: :index, if: -> { params[:allow_guests] }

  load_and_authorize_resource only: %i[create update]

  def index
    if params[:allow_guests]
      render json: serialized_response(Problem.published.allow_guests)
    else
      render json: serialized_response(problems_scope)
    end
  end

  def show
    render json: serialized_response(problem_load)
  end

  def create
    problem = current_v1_user.problems.create!(problem_params)
    render json: serialized_response(problem), status: :created
  end

  def update
    problem = problem_load
    problem.assign_attributes(problem_params)
    problem.integral_update
    render json: serialized_response(problem)
  end

  private

  def problems_scope
    Problem.includes(:interventions).accessible_by(current_ability)
  end

  def problem_load
    problems_scope.find(params[:id])
  end

  def problem_params
    params.require(:problem).permit(:name, :allow_guests, :status_event)
  end
end
