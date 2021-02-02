# frozen_string_literal: true

class V1::TeamSerializer < V1Serializer
  attributes :name
  has_many :users
  has_one :team_admin
end
