# frozen_string_literal: true

class Phone < ApplicationRecord
  has_paper_trail skip: %i[number migrated_number]
  belongs_to :user
  validates :iso, :prefix, :number, presence: true
  before_update :remove_confirmation, if: :number_changed?

  encrypts :number

  def token_correct?(code)
    code == confirmation_code
  end

  def refresh_confirmation_code
    update(confirmation_code: rand.to_s[2..5])
  end

  def confirmed?
    confirmed
  end

  def confirm!
    update(confirmed: true, confirmed_at: DateTime.current)
  end

  private

  def remove_confirmation
    self.confirmed = false
    self.confirmed_at = nil
    self.confirmation_code = nil
  end
end
