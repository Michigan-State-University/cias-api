# frozen_string_literal: true

class V1::ChartsController < V1Controller
  def index
    authorize! :read, Chart

    render json: serialized_response(chart_scope)
  end

  def show
    authorize! :read, Chart

    render json: serialized_response(chart_load)
  end

  def create
    authorize! :create, Chart

    chart = V1::Charts::Create.call(chart_params)
    render json: serialized_response(chart), status: :created
  end

  def update
    authorize! :update, Chart

    chart = V1::Charts::Update.call(chart_load, chart_params)
    render json: serialized_response(chart)
  end

  def destroy
    authorize! :delete, Chart

    V1::Charts::Destroy.call(chart_load)
    head :no_content
  end

  private

  def chart_scope
    Chart.accessible_by(current_ability)
  end

  def chart_load
    chart_scope.find(params[:id])
  end

  def chart_params
    params.require(:chart).permit(:name, :description, :status, :dashboard_section_id, formula: {})
  end
end
