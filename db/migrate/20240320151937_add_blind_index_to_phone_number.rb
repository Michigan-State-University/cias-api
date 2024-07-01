class AddBlindIndexToPhoneNumber < ActiveRecord::Migration[6.1]
  def change
    add_column :phones, :number_bidx, :string
    add_index :phones, :number_bidx

    BlindIndex.backfill(Phone)
  end
end
