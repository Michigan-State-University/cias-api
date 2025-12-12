# frozen_string_literal: true

class V1::Intervention::AssignTags
  def self.call(intervention, tag_ids, tag_names)
    new(intervention, tag_ids, tag_names).call
  end

  def initialize(intervention, tag_ids, tag_names)
    @intervention = intervention
    @tag_ids = tag_ids
    @tag_names = tag_names
  end

  def call
    find_tags_to_add!
    reject_already_assigned_tags!
    create_missing_tags!

    return if tags_to_add.blank?

    intervention.tags << tags_to_add
    tags_to_add
  end

  private

  attr_reader :intervention, :tag_ids, :tag_names
  attr_accessor :tags_to_add

  def tag
    @tag ||= if tag_id.present?
               Tag.find_by(id: tag_id)
             else
               Tag.find_or_create_by(name: tag_name)
             end
  end

  def create_missing_tags!
    return if tag_names.blank?

    @tags_to_add = tags_to_add.to_a

    tag_names.each do |name|
      next if name.blank?

      new_tag = Tag.find_or_create_by(name: name)
      next if new_tag.id.in?(already_assigned_tag_ids)

      tags_to_add << new_tag
    end
  end

  def reject_already_assigned_tags!
    return if tags_to_add.blank?

    @tags_to_add = tags_to_add.where.not(id: intervention.tag_interventions.select(:tag_id))
  end

  def already_assigned_tag_ids
    @already_assigned_tag_ids ||= intervention.tag_interventions.select(:tag_id).pluck(:tag_id)
  end

  def find_tags_to_add!
    return if tag_ids.blank?

    @tags_to_add = Tag.where(id: tag_ids)
  end
end
