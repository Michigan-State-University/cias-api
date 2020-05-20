# frozen_string_literal: true

class DatabaseExtensions < ActiveRecord::Migration[6.0]
  def change
    %w[plpgsql pg_trgm fuzzystrmatch btree_gin btree_gist].each do |ext|
      enable_extension(ext)
    end
  end
end
