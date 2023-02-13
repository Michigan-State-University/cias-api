# frozen_string_literal: true

class V1::Intervention::ExportData
  attr_reader :intervention

  def self.call(intervention)
    new(intervention).call
  end

  def initialize(intervention)
    @intervention = intervention
  end

  def call
    V1::Export::InterventionSerializer.new(intervention).serializable_hash(include: '**')
  end
end
