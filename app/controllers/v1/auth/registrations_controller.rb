# frozen_string_literal: true

class V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  include Resource
  include Log
  prepend Auth::Default
end
