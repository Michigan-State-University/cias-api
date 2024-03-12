# frozen_string_literal: true

class AddColumnsToClinicLocationForEpicIdentifiers < ActiveRecord::Migration[6.1]
  def change
    add_column :clinic_locations, :epic_identifier, :text, default: ''
    add_column :clinic_locations, :auxiliary_epic_identifier, :text, default: ''
  end
end
