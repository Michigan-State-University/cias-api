# frozen_string_literal: true

class DisableDatabaseExtensions < ActiveRecord::Migration[6.0]
  def up
    %w[btree_gist fuzzystrmatch pg_trgm pgcrypto plpgsql].each do |ext|
      disable_extension(ext)
    end
  end

  def down
    %w[btree_gist fuzzystrmatch pg_trgm pgcrypto plpgsql].each do |ext|
      enable_extension(ext)
    end
  end
end
