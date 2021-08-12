class CreateCatMhTestTypeTimeFrames < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_test_type_time_frames do |t|
      t.integer :cat_mh_time_frame_id
      t.integer :cat_mh_test_type_id
      t.belongs_to :cat_mh_time_frames, foreign_key: true
      t.belongs_to :cat_mh_test_types, foreign_key: true
      t.timestamps
    end
  end
end
