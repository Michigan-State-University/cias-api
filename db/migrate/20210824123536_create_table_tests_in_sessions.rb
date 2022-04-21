class CreateTableTestsInSessions < ActiveRecord::Migration[6.0]
  def change
    create_table :tests do |t|
      t.belongs_to :session, type: :uuid
      t.belongs_to :cat_mh_test_type
      t.timestamps
    end
  end
end
