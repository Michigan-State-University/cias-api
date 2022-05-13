# frozen_string_literal: true

class CatMhPopulation < ApplicationRecord
  has_many :sessions, inverse_of: :cat_mh_population, class_name: 'Session::CatMh', dependent: :destroy
end
