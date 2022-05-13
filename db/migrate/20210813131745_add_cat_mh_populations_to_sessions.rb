class AddCatMhPopulationsToSessions < ActiveRecord::Migration[6.0]
  def change
    add_reference :sessions, :cat_mh_population, null: true, foreign_key: true
  end
end
