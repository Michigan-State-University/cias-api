# frozen_string_literal: true

class V1::ChartsController < V1Controller
  include Resource::Clone
  include Resource::Position

  def index
    authorize! :read, Chart

    render json: serialized_response(charts_scope)
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

  def regenerate
    authorize! :update, Chart

    chart = chart_load

    raise ActiveRecord::RecordNotSaved, I18n.t('chart.error.regenerate.draft_chart') if chart.draft?

    # CHECK the lock, never acquire it: CreateForUserSessions SKIPS when it is already held, so
    # acquiring here would make the job skip its own work and leave the chart wedged.
    raise ActiveRecord::RecordNotSaved, I18n.t('chart.error.regenerate.in_progress') if chart.regenerating?

    RegenerateChartsJob.perform_later([chart.id], replace: true, user_id: current_v1_user.id)

    head :accepted
  end

  private

  def charts_scope
    Chart.accessible_by(current_ability)
  end

  def chart_load
    charts_scope.find(params[:id])
  end

  def chart_params
    params.require(:chart).permit(:name, :description, :chart_type, :trend_line, :status, :dashboard_section_id,
                                  :interval_type, :date_range_start, :date_range_end, formula: {})
  end
end
