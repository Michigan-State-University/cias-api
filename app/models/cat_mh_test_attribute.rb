# frozen_string_literal: true

class CatMhTestAttribute < ApplicationRecord
  has_many :cat_mh_variables, dependent: :destroy
  has_many :cat_mh_test_types, through: :cat_mh_variables
end
