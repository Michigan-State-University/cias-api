class MigrateSmsSessionsToSeparateTable < ActiveRecord::Migration[6.1]
  def up
    create_table :sms_codes, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.references :session, null: false, foreign_key: true, type: :uuid
      t.references :health_clinic, foreign_key: true, type: :uuid
      t.boolean :active, default: true
      t.string :sms_code

      t.timestamps
    end

    Session.where.not(sms_code: nil).all.each do |session|
      SmsCode.create!(sms_code: session.sms_code, session_id: session.id, active: true)
    end

    execute <<-SQL.squish
          CREATE UNIQUE INDEX unique_active_sms_codes
            ON sms_codes (sms_code) WHERE active IS TRUE;
    SQL

    remove_column :sessions, :sms_code
  end

  def down
    add_column :sessions, :sms_code, :string

    Session.left_joins(:sms_codes).where.not(sms_codes: {sms_code: nil}).each do |session|
      session.update!(sms_code: session.sms_codes.first.sms_code)
    end

    execute <<-SQL.squish
          DROP INDEX IF EXISTS unique_active_sms_codes;
    SQL

    drop_table :sms_codes
  end
end
