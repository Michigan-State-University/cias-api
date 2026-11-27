# frozen_string_literal: true

class CreateParticipantUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :participant_uploads, id: :uuid, default: -> { 'uuid_generate_v4()' } do |t|
      t.references :user_session, type: :uuid, null: false, foreign_key: true, index: false
      t.references :question, type: :uuid, null: false, foreign_key: true, index: true
      t.text :original_filename_ciphertext, null: false
      t.text :description_ciphertext
      t.string :content_type_detected, null: false
      t.bigint :byte_size, null: false
      t.string :scan_status, null: false, default: 'pending'
      t.integer :scan_attempts, null: false, default: 0
      t.string :moderation_status, null: false, default: 'pending'
      t.text :moderation_labels_ciphertext
      t.string :moderation_model_version
      t.string :moderation_skip_reason
      t.datetime :moderated_at
      t.datetime :deleted_at
      t.string :deletion_reason

      t.timestamps
    end

    add_index :participant_uploads, %i[user_session_id question_id]
    add_index :participant_uploads, :scan_status
  end
end
