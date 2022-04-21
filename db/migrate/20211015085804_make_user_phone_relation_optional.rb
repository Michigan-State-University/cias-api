class MakeUserPhoneRelationOptional < ActiveRecord::Migration[6.0]
  def change
    change_column_null(:phones, :user_id, true)
  end
end
