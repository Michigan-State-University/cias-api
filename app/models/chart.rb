class Chart < ApplicationRecord
  extend DefaultValues

  belongs_to :organization

  attribute :formula, :json, default: assign_default_values('formula')

  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }

  enum status: { draft: 'draft', published: 'published', closed: 'closed', archived: 'archived' }

  def json_schema_path
    @json_schema_path ||= 'db/schema/chart'
  end

  def integral_update
    return if published?

    save!
  end
end
