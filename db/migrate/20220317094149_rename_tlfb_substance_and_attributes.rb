# frozen_string_literal: true

class RenameTlfbSubstanceAndAttributes < ActiveRecord::Migration[6.1]
  def change
    rename_table :substances, :consumption_results
  end
end
