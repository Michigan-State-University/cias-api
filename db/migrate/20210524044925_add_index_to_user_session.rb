# frozen_string_literal: true

class AddIndexToUserSession < ActiveRecord::Migration[6.0]
  def change
    remove_index :user_sessions, %i[user_id session_id]
    add_index :user_sessions, %i[user_id session_id health_clinic_id], unique: true, name: 'index_user_session_on_u_id_and_s_id_and_hc_id'
  end
end
