# frozen_string_literal: true

class CatMhTimeFrame < ApplicationRecord
  has_many :cat_mh_test_type_time_frames, dependent: :destroy
end
