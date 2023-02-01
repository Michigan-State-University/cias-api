# frozen_string_literal: true

class ShortLink < ApplicationRecord
  belongs_to :linkable, polymorphic: true
  belongs_to :health_clinic, optional: true
  validates :name, uniqueness: true
end
