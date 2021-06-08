# frozen_string_literal: true

class V1::Auth::ConfirmationsController < DeviseTokenAuth::ConfirmationsController
  include Resource
  include Log
  prepend Auth::Default
end
