# frozen_string_literal: true

class V1::Intervention::Update
  def initialize(intervention, params)
    @intervention = intervention
    @params = params
  end

  def execute
    ActiveRecord::Base.transaction do
      assign_locations!
      intervention.assign_attributes(params)
      intervention.save!
    end

    intervention
  end

  private

  attr_accessor :intervention
  attr_reader :params

  def assign_locations!
    return unless params.key?(:location_ids)

    intervention.intervention_locations.destroy_all
    params.delete(:location_ids)&.each { |location_id| intervention.intervention_locations.create!(clinic_location_id: location_id) }
  end
end
