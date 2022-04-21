# frozen_string_literal: true

require 'csv'

class Intervention::Csv
  attr_reader :sessions_scope
  attr_accessor :data

  def self.call(intervention)
    new(intervention).call
  end

  def initialize(intervention)
    @sessions_scope = data_scope(intervention)
  end

  def call
    collect_data
    generate
  end

  private

  def data_scope(intervention)
    intervention.sessions.order(:position)
  end

  def collect_data
    self.data = Harvester.new(sessions_scope).collect
  end

  def generate
    CSV.generate do |csv|
      csv << data.header
      data.rows&.each { |row| csv << row }
    end
  end
end
