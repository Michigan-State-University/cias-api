class CreateCatMhPopulations < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_populations do |t|
      t.string :name

      t.timestamps
    end
  end
end
