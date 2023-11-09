# frozen_string_literal: true

module Intervention::StatusesTransition
  extend ActiveSupport::Concern

  STATUSES = {
    draft: 'draft',
    published: 'published',
    closed: 'closed',
    archived: 'archived',
    paused: 'paused'
  }.freeze

  public_constant :STATUSES

  included do
    include AASM

    aasm column: :status, whiny_transitions: true, enum: true do
      state :draft, initial: true
      state :published
      state :closed
      state :archived
      state :paused

      event :published do
        transitions from: %i[draft paused], to: :published
      end

      event :closed do
        transitions from: :published, to: :closed
      end

      event :archived do
        transitions from: %i[draft closed], to: :archived
      end

      event :paused do
        transitions from: :published, to: :paused
      end

      event :draft do
        transitions from: [], to: %i[published archived]
      end
    end
  end
end
