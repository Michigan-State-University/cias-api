# frozen_string_literal: true

class V1::Positions::Update
  def self.call(scope, values)
    new(scope, values).call
  end

  def initialize(scope, values)
    @scope = scope
    @rows = V1::Positions::Rows.new(values)
  end

  def call
    ids = rows.ids
    return if ids.empty?

    V1::Positions.ensure_in_scope!(scope, ids)
    scope.where(id: ids).update_all( # rubocop:disable Rails/SkipsModelValidations
      position: V1::Positions.case_by_id(scope.klass.arel_table, rows.mapping(:position)),
      updated_at: Time.current
    )
  end

  private

  attr_reader :scope, :rows
end
