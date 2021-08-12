# frozen_string_literal: true

class CatMhTestType < ApplicationRecord
  has_many :cat_mh_test_type_languages, dependent: :destroy
  has_many :cat_mh_test_type_time_frames, dependent: :destroy
  has_many :cat_mh_languages, through: :cat_mh_test_type_languages
  has_many :cat_mh_time_frames, through: :cat_mh_test_type_time_frames
  belongs_to :cat_mh_population, dependent: :destroy
end
