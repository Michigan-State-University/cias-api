# frozen_string_literal: true

class Test < ApplicationRecord
  belongs_to :session, class_name: 'Session::CatMh'
  belongs_to :cat_mh_test_type
end
