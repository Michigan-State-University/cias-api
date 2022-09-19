# frozen_string_literal: true

class LiveChat::Interventions::Navigator < ApplicationRecord
  self.table_name = 'intervention_navigators'

  belongs_to :intervention
  belongs_to :user
end
