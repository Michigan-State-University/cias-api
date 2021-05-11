# frozen_string_literal: true

class AddHealthClinicToUserSession < ActiveRecord::Migration[6.0]
  def change
    add_reference :user_sessions, :health_clinic, null: true, foreign_key: true, type: :uuid
  end
end
