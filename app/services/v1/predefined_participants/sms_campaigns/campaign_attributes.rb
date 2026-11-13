# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::CampaignAttributes
  LINK_ATTRIBUTES = %i[url variable link_type].freeze

  def initialize(params)
    @params = params
  end

  def kind
    @params[:kind].to_s
  end

  def body
    @body ||= normalized_body(@params[:body])
  end

  def links
    @links ||= links_of(@params)
  end

  def reminder
    @params[:scheduled_reminder]
  end

  def reminder?
    reminder.present?
  end

  def reminder_body
    @reminder_body ||= normalized_body(reminder[:body])
  end

  def reminder_links
    @reminder_links ||= links_of(reminder)
  end

  def days_after
    Integer(reminder[:days_after].to_s, exception: false)
  end

  private

  def normalized_body(value)
    raw = value.to_s
    raw.valid_encoding? ? raw.unicode_normalize(:nfc) : ''
  end

  def links_of(source)
    Array(source[:links]).map { |link| link_attributes(link) }
  end

  def link_attributes(link)
    hash = link.respond_to?(:to_unsafe_h) ? link.to_unsafe_h : link.to_h
    hash.with_indifferent_access.slice(*LINK_ATTRIBUTES).compact_blank
  end
end
