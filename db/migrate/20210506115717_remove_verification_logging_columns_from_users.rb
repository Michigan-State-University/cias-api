class RemoveVerificationLoggingColumnsFromUsers < ActiveRecord::Migration[6.0]
  def change
    reversible do |dir|
      change_table :users do |t|
        dir.up do
          t.remove :verification_code
          t.remove :verification_code_created_at
          t.remove :confirmed_verification
        end

        dir.down do
          t.remove :verification_code
          t.remove :verification_code_created_at
          t.remove :confirmed_verification
        end
      end
    end
  end
end
