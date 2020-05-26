# frozen_string_literal: true

class DatabaseExtensions < ActiveRecord::Migration[6.0]
  def change
    %w[btree_gin btree_gist fuzzystrmatch pg_trgm pgcrypto plpgsql uuid-ossp].each do |ext|
      enable_extension(ext)
    end
  end
end
