# frozen_string_literal: true

class Chart < ApplicationRecord
  has_paper_trail
  extend DefaultValues
  include Clone

  belongs_to :dashboard_section
  has_many :chart_statistics, dependent: :destroy

  attribute :formula, :json, default: assign_default_values('formula')
  attribute :position, :integer, default: 1

  validates :formula, presence: true, json: { schema: lambda {
                                                        Rails.root.join("#{json_schema_path}/formula.json").to_s
                                                      }, message: lambda { |err|
                                                                    err
                                                                  } }

  enum status: { draft: 'draft', data_collection: 'data_collection', published: 'published' }
  enum chart_type: { bar_chart: 'bar_chart', pie_chart: 'pie_chart', percentage_bar_chart: 'percentage_bar_chart' }

  default_scope { order(:position) }
  after_update_commit :status_change

  def integral_update(chart_params)
    return if published?

    assign_attributes(chart_params)
    save!
  end

  def status_change
    return unless saved_change_to_attribute?(:status)

    CreateChartStatisticsJob.perform_later(id) if status == 'data_collection'
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/chart'
  end
end
