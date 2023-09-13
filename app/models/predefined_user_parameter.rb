# frozen_string_literal: true

class PredefinedUserParameter < ApplicationRecord
  belongs_to :user
  belongs_to :intervention
  belongs_to :health_clinic, optional: true

  validates :slug, uniqueness: true

  before_create :generate_slug

  def generate_slug(suggested_slug = nil)
    suggested_slug ||= SecureRandom.base58(4)

    if PredefinedUserParameter.where(slug: suggested_slug).any?
      generate_slug(suggested_slug + SecureRandom.base58(2))
    else
      self.slug = suggested_slug
    end
  end
end
