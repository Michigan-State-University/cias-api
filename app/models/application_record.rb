# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ATTRS_NO_TO_SERIALIZE = %w[id user_id created_at updated_at].freeze

  def self.attrs_to_nil
    column_names.without(*ATTRS_NO_TO_SERIALIZE).index_with { |_x| nil }
  end
end
