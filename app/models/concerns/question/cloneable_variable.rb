# frozen_string_literal: true

module Question::CloneableVariable
  extend ActiveSupport::Concern

  included do
    def variable_clone_prefix(taken_variables)
      return unless body['variable']['name'].presence

      new_variable = "clone_#{body['variable']['name']}"
      new_variable = variable_with_clone_index(taken_variables, body['variable']['name']) if taken_variables.include?(new_variable)
      body['variable']['name'] = new_variable
    end
  end
end
