# frozen_string_literal: true

class Link < ApplicationRecord
  include Rails.application.routes.url_helpers

  validates :url, presence: true
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
  validates :slug, uniqueness: true
  validates :slug, length: { within: 3..255, on: :create }

  before_validation :generate_slug

  def short
    Rails.application.routes.url_helpers.v1_short_url(slug: slug)
  end

  def generate_slug
    self.slug = SecureRandom.base58(6) if slug.blank?
  end

  def self.shorten(url, slug = '')
    raise ActiveRecord::ActiveRecordError, I18n.t('activerecord.errors.models.link.slug.too_long') if slug.length > 255

    link = if slug.blank?
             Link.find_or_initialize_by(url: url)
           else
             Link.find_or_initialize_by(url: url, slug: slug)
           end
    return link.short if link.save

    Link.shorten(url, slug + SecureRandom.base58(2))
  end
end
