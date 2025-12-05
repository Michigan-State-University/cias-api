# frozen_string_literal: true

class Import::Basic::TagService
  include ImportOperations

  def self.call(intervention_id, tag_hash)
    new(
      intervention_id,
      tag_hash
    ).call
  end

  def initialize(intervention_id, tag_hash)
    @intervention_id = intervention_id
    @tag_hash = tag_hash
  end

  attr_reader :intervention_id, :tag_hash

  def call
    tag = Tag.find_or_create_by(name: tag_hash[:name])
    TagIntervention.create(intervention_id: intervention_id, tag_id: tag.id)
  end
end
