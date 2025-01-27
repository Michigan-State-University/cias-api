# frozen_string_literal: true

class V1::Intervention::Update
  def initialize(intervention, params)
    @intervention = intervention
    @params = params
  end

  def execute
    status_transition_validation

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

  def status
    @status ||= params[:status]
  end

  def status_transition_validation
    return if status.blank?
    return if intervention.public_send(:"may_#{status}?")

    raise ActiveRecord::ActiveRecordError,
          I18n.t('activerecord.errors.models.intervention.attributes.status_transition', current_status: intervention.status, new_status: status)
  end
end
