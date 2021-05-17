# frozen_string_literal: true

class Chart < ApplicationRecord
  extend DefaultValues

  belongs_to :dashboard_section
  has_many :chart_statistics, dependent: :destroy

  attribute :formula, :json, default: assign_default_values('formula')

  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }

  enum status: { draft: 'draft', data_collection: 'data_collection', published: 'published' }
  enum chart_type: { bar_chart: 'bar_chart', pie_chart: 'pie_chart' }

  def integral_update
    return if published?

    save!
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/chart'
  end
end
