class CreateCatMhTestTypeTimeFrames < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_test_type_time_frames do |t|
      t.integer :cat_mh_time_frame_id
      t.integer :cat_mh_test_type_id
      t.timestamps
    end
  end
end
