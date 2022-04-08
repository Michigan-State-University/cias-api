class CreateCatMhTimeFrames < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_time_frames do |t|
      t.integer :timeframe_id
      t.string :description
      t.string :short_name

      t.timestamps
    end
  end
end
