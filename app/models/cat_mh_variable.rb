# frozen_string_literal: true

class CatMhVariable < ApplicationRecord
  belongs_to :cat_mh_test_attribute
  belongs_to :cat_mh_test_type
end
