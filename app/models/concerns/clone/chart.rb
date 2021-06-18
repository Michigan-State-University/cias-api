# frozen_string_literal: true

class Clone::Chart < Clone::Base
  def execute
    outcome.status = :draft
    outcome.save!
    outcome
  end
end
