# frozen_string_literal: true

class AddParticipantIdToGeneratedReports < ActiveRecord::Migration[6.0]
  def change
    add_column :generated_reports, :participant_id, :uuid
    remove_column :generated_reports, :shown_for_participant, :boolean

    add_index :generated_reports, :participant_id
  end
end
