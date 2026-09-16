# frozen_string_literal: true

require 'csv'

class Intervention::Csv
  attr_reader :sessions_scope, :period
  attr_accessor :data

  def self.call(intervention, period)
    new(intervention, period).call
  end

  def initialize(intervention, period)
    @sessions_scope = data_scope(intervention)
    @period = period
  end

  def call
    collect_data
    generate
  end

  private

  def data_scope(intervention)
    intervention.sessions.includes(:intervention, :questions, sms_plans: :sms_links).order(:position)
  end

  def collect_data
    self.data = Harvester.new(sessions_scope, period).collect
  end

  def generate
    CSV.generate do |csv|
      csv << data.header
      data.rows&.each { |row| csv << row }
    end
  end
end
