# frozen_string_literal: true

class Link < ApplicationRecord
  include Rails.application.routes.url_helpers

  validates :url, presence: true
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :slug, uniqueness: true
  validates :slug, length: { within: 3..255, on: :create, message: 'too long' }

  before_validation :generate_slug

  def short
    Rails.application.routes.url_helpers.v1_short_url(slug: slug)
  end

  def generate_slug
    self.slug = SecureRandom.uuid[0..5] if slug.blank?
  end

  def self.shorten(url, slug = '')
    link = slug.blank? ? Link.find_by(url: url) : Link.find_by(url: url, slug: slug)
    return link.short if link

    link = Link.new(url: url, slug: slug)
    return link.short if link.save

    Link.shorten(url, slug + SecureRandom.uuid[0..2])
  end
end
