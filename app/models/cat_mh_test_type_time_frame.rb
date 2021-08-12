# frozen_string_literal: true

class CatMhTestTypeTimeFrame < ApplicationRecord
  belongs_to :cat_mh_time_frame
  belongs_to :cat_mh_test_type
end
