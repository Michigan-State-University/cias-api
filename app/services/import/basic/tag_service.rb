# frozen_string_literal: true

class Import::Basic::TagService
  include ImportOperations

  def self.call(intervention_id, tag_hash, user)
    new(
      intervention_id,
      tag_hash,
      user
    ).call
  end

  def initialize(intervention_id, tag_hash, user)
    @intervention_id = intervention_id
    @tag_hash = tag_hash
    @user = user
  end

  attr_reader :intervention_id, :tag_hash, :user

  def call
    tag = Tag.find_or_create_by(name: tag_hash[:name], user: user)
    TagIntervention.create(intervention_id: intervention_id, tag_id: tag.id)
  end
end
