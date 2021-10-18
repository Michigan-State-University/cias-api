class AddFilledSessionCountToIntervention < ActiveRecord::Migration[6.0]
  def change
    add_column :interventions, :created_cat_mh_session_count, :integer, default: 0
  end
end
