# frozen_string_literal: true

module V1::Positions
  def self.case_by_id(table, mapping)
    mapping.reduce(Arel::Nodes::Case.new(table[:id])) { |node, (id, value)| node.when(id).then(value) }
  end

  def self.ensure_in_scope!(scope, ids)
    return if scope.where(id: ids).count == ids.size

    raise ActiveRecord::RecordNotFound.new("Couldn't find #{scope.klass.name}", scope.klass.name)
  end
end
