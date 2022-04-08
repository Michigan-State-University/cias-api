class AddCatMhTimeFramesToSessions < ActiveRecord::Migration[6.0]
  def change
    add_reference :sessions, :cat_mh_time_frame, null: true, foreign_key: true
  end
end
