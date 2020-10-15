# frozen_string_literal: true

class V1::Interventions::Index < BaseSerializer
  def cache_key
    "interventions/#{interventions.count}-#{interventions.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    {
      interventions: collect_interventions
    }
  end

  private

  attr_reader :interventions

  def collect_interventions
    interventions.map do |intervention|
      V1::Interventions::Show.new(intervention: intervention).to_json
    end
  end
end
