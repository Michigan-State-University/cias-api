# frozen_string_literal: true

class V1::ShortLinks::MapService
  def initialize(name)
    @name = name
  end

  def self.call(name)
    new(name).call
  end

  attr_reader :name

  def call
    {
      data: {
        intervention_id: intervention.id,
        health_clinic_id: short_link.health_clinic_id,
        type: object.type,
        first_session_id: first_session_id
      }
    }.to_json
  end

  private

  def first_session_id
    return nil unless object.type.eql?('Intervention')

    object.sessions.order(:position).first&.id
  end

  def object
    @object ||= short_link.linkable
  end

  def short_link
    @short_link ||= ShortLink.find_by!(name: name)
  end

  def intervention
    Intervention.joins(:short_links).find_by!(status: 'published', short_links: { name: name })
  end
end
