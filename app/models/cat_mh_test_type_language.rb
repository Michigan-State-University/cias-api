# frozen_string_literal: true

class CatMhTestTypeLanguage < ApplicationRecord
  belongs_to :cat_mh_language
  belongs_to :cat_mh_test_type
end
