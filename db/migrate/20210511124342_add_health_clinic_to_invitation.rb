# frozen_string_literal: true

class AddHealthClinicToInvitation < ActiveRecord::Migration[6.0]
  def change
    add_reference :invitations, :health_clinic, null: true, foreign_key: true, type: :uuid
  end
end
