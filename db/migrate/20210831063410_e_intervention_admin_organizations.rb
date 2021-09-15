# frozen_string_literal: true

class EInterventionAdminOrganizations < ActiveRecord::Migration[6.0]
  def change
    create_table :e_intervention_admin_organizations do |t|
      t.belongs_to :user, type: :uuid
      t.belongs_to :organization, type: :uuid

      t.timestamps
    end

    Rake::Task['one_time_use:assign_e_int_admins'].invoke
  end
end
