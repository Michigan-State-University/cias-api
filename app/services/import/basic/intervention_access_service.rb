# frozen_string_literal: true

class Import::Basic::InterventionAccessService
  include ImportOperations
  def self.call(intervention_id, access_hash)
    new(
      intervention_id,
      access_hash.except(:version)
    ).call
  end

  def initialize(intervention_id, access_hash)
    @intervention_id = intervention_id
    @access_hash = access_hash
  end

  attr_reader :access_hash, :intervention_id

  def call
    InterventionAccess.create!(access_hash.merge({ intervention_id: intervention_id }))
  end
end
