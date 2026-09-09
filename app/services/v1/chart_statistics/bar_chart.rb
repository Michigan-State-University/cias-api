# frozen_string_literal: true

class V1::ChartStatistics::BarChart < V1::ChartStatistics::Base
  attr_reader :data_offset

  def initialize(charts_data_collection, charts, data_offset = nil)
    super(charts_data_collection, charts)
    @data_offset = data_offset
  end

  def chart_statistics(aggregated_data, chart)
    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    periodical_statistics(aggregated_data, patterns, default_pattern, chart)
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, date| hash[date] = Hash.new { |hash, label| hash[label] = 0 } } }.tap do |hash|
      statistics_query = charts_data_collection
                           .joins('LEFT JOIN charts ON chart_statistics.chart_id = charts.id')
                           .group('chart_statistics.chart_id, chart_statistics.label, period_label, charts.interval_type')
                           .select("chart_statistics.chart_id,
                                    chart_statistics.label,
                                    date_trunc((select
                                                  case
                                                      when charts.interval_type = 'monthly' then 'month'
                                                      when charts.interval_type = 'quarterly' then 'quarter'
                                                  end),
                                                chart_statistics.filled_at) AS period_label,
                                    COUNT(chart_statistics.label),
                                    charts.interval_type")
                           .to_sql
      results = ActiveRecord::Base.connection.execute(statistics_query).to_a
      results.each do |data_statistic|
        hash[data_statistic['chart_id']][monthly_or_quarterly_key(data_statistic['interval_type'], data_statistic['period_label'])][data_statistic['label']] =
          data_statistic['count']
      end
    end
  end
  # rubocop:enable Lint/ShadowingOuterLocalVariable

  def periodical_statistics(aggregated_data, patterns, default_pattern, chart)
    statistics = []
    if data_offset.present?
      current_month = Time.current - data_offset.to_i.days
      current_month = current_month.beginning_of_month
      end_month = Time.current.beginning_of_month
    else
      ordered_data = charts_data_collection.ordered_data_for_chart(chart.id)
      current_month = first_month(ordered_data)&.beginning_of_month
      end_month = last_month(ordered_data)&.beginning_of_month
    end

    return [] if current_month.nil?

    current_month = current_month.to_date
    while current_month <= end_month
      label = monthly_or_quarterly_label(chart, current_month)
      value = aggregated_data[label]
      statistics << data_for_chart(label, value, patterns, default_pattern)

      current_month = chart.quarterly? ? current_month.next_quarter.beginning_of_quarter : current_month.next_month
    end
    statistics
  end

  def first_month(ordered_data)
    ordered_data&.first&.filled_at
  end

  def last_month(ordered_data)
    ordered_data&.last&.filled_at
  end

  def monthly_or_quarterly_key(interval_type, date)
    interval_type == 'quarterly' ? "Q#{(date.month / 3.0).ceil} #{date.year}" : date.strftime('%B %Y')
  end

  def monthly_or_quarterly_label(chart, date)
    chart.quarterly? ? "Q#{(date.month / 3.0).ceil} #{date.year}" : date.strftime('%B %Y')
  end
end
