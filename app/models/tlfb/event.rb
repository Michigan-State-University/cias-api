# frozen_string_literal: true

class Tlfb::Event < ApplicationRecord
  belongs_to :day, class_name: 'Tlfb::Day'
end
