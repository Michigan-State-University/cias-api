# frozen_string_literal: true

class V1::Intervention::AttachFiles
  def self.call(intervention, files)
    new(intervention, files).call
  end

  def initialize(intervention, files)
    @intervention = intervention
    @files = files
  end

  def call
    files&.each do |file|
      intervention.files.attach(file)
    end
  end

  private

  attr_accessor :intervention, :files
end
