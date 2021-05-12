# frozen_string_literal: true

class CreateUserVerificationCodes < ActiveRecord::Migration[6.0]
  def change
    create_table :user_verification_codes, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, index: true, foreign_key: true
      t.string :code, null: false
      t.boolean :confirmed, null: false, default: false

      t.timestamps
    end
  end
end
