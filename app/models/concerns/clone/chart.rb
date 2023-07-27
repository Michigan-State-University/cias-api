# frozen_string_literal: true

class Clone::Chart < Clone::Base
  def execute
    outcome.status = :draft
    outcome.position = Chart.where(dashboard_section_id: outcome.dashboard_section_id).maximum(:position)&.next || 1
    outcome.save!
    outcome
  end
end
