# frozen_string_literal: true

class UserProblem < ApplicationRecord
  belongs_to :user, inverse_of: :user_problems
  belongs_to :problem, inverse_of: :user_problems
end
