class AddFkToCatMhTestTypeTimeFrames < ActiveRecord::Migration[6.0]
  def change
    add_foreign_key :cat_mh_test_type_time_frames, :cat_mh_time_frames, column: :cat_mh_time_frame_id
    add_foreign_key :cat_mh_test_type_time_frames, :cat_mh_test_types, column: :cat_mh_test_type_id
  end
end
