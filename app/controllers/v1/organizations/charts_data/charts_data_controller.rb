# frozen_string_literal: true

class V1::Organizations::ChartsData::ChartsDataController < V1Controller
  def generate_charts_data
    authorize! :read, ChartStatistic


    data_collection = charts_data_collection
    charts = load_charts

    charts_data = V1::ChartStatistics::GenerateStatistics.new(data_collection, charts, date_offset)
                                                             .generate_statistics

    render json: charts_data_response(charts_data)
  end

  def generate_chart_data
    authorize! :read, ChartStatistic
    chart = load_chart
    data_collection = charts_data_collection

    result = V1::ChartStatistics::GenerateStatistics.new(data_collection, chart)
                                                         .generate_statistic_for_chart
    render json: result
  end

  private

  def organization
    @organization ||= Organization.accessible_by(current_ability).find(params[:organization_id])
  end

  def charts_data_params
    params.permit(:date_offset, clinic_ids: [])
  end

  def date_offset
    charts_data_params[:date_offset]
  end

  def start_date
    Time.current - date_offset.to_i.days
  end

  def end_date
    Time.current
  end

  def date_range
    start_date.beginning_of_day..end_date.end_of_day
  end

  def clinic_ids
    charts_data_params[:clinic_ids]
  end

  def chart_id
    params[:chart_id]
  end

  def load_chart_statistics
    ChartStatistic.accessible_by(current_ability).where(chart_id: chart_id)
  end

  def load_chart
    Chart.find_by(id: chart_id)
  end

  def load_charts
    Chart.accessible_by(current_ability)
  end

  def charts_data_collection
    data_collection = ChartStatistic.accessible_by(current_ability).where(organization_id: organization.id)
    data_collection = data_collection&.where(health_clinic_id: clinic_ids) if clinic_ids.present?
    data_collection = data_collection&.where(chart_id: chart_id) if chart_id.present?
    data_collection = data_collection&.where(created_at: date_range) if date_offset.present?
    data_collection&.joins(:chart)
  end

  def pie_charts_data_collection(data_collection)
    data_collection&.where(charts: { chart_type: 'pie_chart' })
  end

  def bar_charts_data_collection(data_collection)
    data_collection&.where(charts: { chart_type: %w[bar_chart percentage_bar_chart] })
  end

  def bar_chart_data_collection(data_collection)
    bar_charts_data_collection(data_collection).where(chart_id: chart_id)
  end

  def pie_chart_data_collection(data_collection)
    pie_charts_data_collection(data_collection).where(chart_id: chart_id)
  end

  def charts_data_response(charts_data)
    {
      'data_for_charts' => charts_data
    }
  end
end
