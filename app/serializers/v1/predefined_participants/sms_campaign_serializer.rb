# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaignSerializer < V1Serializer
  PARENT_IN_FLIGHT = %w[scheduled sending].freeze

  attributes :kind, :status, :scheduled_at, :sent_at, :accepted_count, :failed_count, :recipients_count, :body

  attribute :scheduled_at_provisional do |object|
    object.scheduled_reminder? && PARENT_IN_FLIGHT.include?(object.parent_campaign&.status)
  end

  attribute :links do |object|
    object.sms_links.sort_by { |link| [link.created_at, link.id] }
          .map { |link| { url: link.url, variable: link.variable, link_type: link.link_type } }
  end
end
