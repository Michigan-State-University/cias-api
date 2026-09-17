# frozen_string_literal: true

class Clone::Chart < Clone::Base
  def execute
    outcome.status = :draft
    outcome.regenerating_since = nil # a clone must never inherit the source's in-progress lock
    outcome.position = Chart.where(dashboard_section_id: outcome.dashboard_section_id).maximum(:position)&.next || 1
    outcome.save!
    outcome
  end
end
