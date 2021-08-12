# frozen_string_literal: true

class CatMhLanguage < ApplicationRecord
  has_many :cat_mh_test_type_languages, dependent: :destroy
end
