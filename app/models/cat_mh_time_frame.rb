# frozen_string_literal: true

class CatMhTimeFrame < ApplicationRecord
  has_many :cat_mh_test_type_time_frames, dependent: :destroy
  has_many :sessions, inverse_of: :cat_mh_time_frame, class_name: 'Session::CatMh', dependent: :destroy
end
