# frozen_string_literal: true

class RemoveThirdPartyIdFromGeneratedReports < ActiveRecord::Migration[6.0]
  Rake::Task['one_time_use:move_third_party_id_to_new_table'].invoke
  def change
    remove_column :generated_reports, :third_party_id, :uuid
  end
end
