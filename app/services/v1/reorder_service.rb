# frozen_string_literal: true

class V1::ReorderService
  def self.call(data_scope, params)
    new(data_scope, params).call
  end

  def initialize(data_scope, params)
    @scope = data_scope
    @params = params
  end

  def call
    scope.klass.transaction do
      params.each { |param| scope.find(param['id']).update!(position: param['position']) }
    end
  end

  attr_reader :scope, :params
end
