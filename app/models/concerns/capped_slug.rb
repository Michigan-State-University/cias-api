# frozen_string_literal: true

module CappedSlug
  extend ActiveSupport::Concern

  EXTENSION_LENGTH = 2
  MAX_EXTENSIONS = 2

  class Exhausted < StandardError; end

  class_methods do
    def max_slug_length
      self::SLUG_LENGTH + (MAX_EXTENSIONS * EXTENSION_LENGTH)
    end

    def slug_length_for_round(round)
      self::SLUG_LENGTH + (EXTENSION_LENGTH * round)
    end

    def slug_rounds
      MAX_EXTENSIONS + 1
    end
  end

  def generate_slug
    return slug if slug.present?

    candidate = SecureRandom.base58(self.class::SLUG_LENGTH)
    (MAX_EXTENSIONS + 1).times do |round|
      candidate += SecureRandom.base58(EXTENSION_LENGTH) if round.positive?
      return self.slug = candidate unless self.class.exists?(slug: candidate)
    end
    raise Exhausted, "#{self.class.name} slug space exhausted"
  end
end
