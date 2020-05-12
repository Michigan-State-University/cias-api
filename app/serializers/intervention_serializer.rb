# frozen_string_literal: true

class InterventionSerializer
  include FastJsonapi::ObjectSerializer
  include InterfaceSerializer
  attributes :type, :name, :settings
end
