# frozen_string_literal: true

class Collaborator < ApplicationRecord
  has_paper_trail
  belongs_to :intervention, touch: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: :intervention_id, message: I18n.t('activerecord.errors.models.collaborator.attributes.user.already_exist') }
end
