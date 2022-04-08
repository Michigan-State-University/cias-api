# frozen_string_literal: true

# module used to run service actions in (single) database transactions
# should be used with "prepend"
module Database::Transactional
  # overrides a method in a class its prepended to that contains a call() method and runs it in transaction block
  def call
    ActiveRecord::Base.transaction { super }
  end
end
