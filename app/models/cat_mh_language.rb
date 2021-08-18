# frozen_string_literal: true

class CatMhLanguage < ApplicationRecord
  has_many :cat_mh_test_type_languages, dependent: :destroy
  has_many :sessions, inverse_of: :cat_mh_language, class_name: 'Session::CatMh', dependent: :destroy
end
