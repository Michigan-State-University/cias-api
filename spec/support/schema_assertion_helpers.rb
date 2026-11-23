# frozen_string_literal: true

module SchemaAssertionHelpers
  def conn
    ActiveRecord::Base.connection
  end

  def expect_unique_violation(&block)
    expect { ActiveRecord::Base.transaction(requires_new: true, &block) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  def expect_not_null_violation(&block)
    expect { ActiveRecord::Base.transaction(requires_new: true, &block) }.to raise_error(ActiveRecord::NotNullViolation)
  end
end
