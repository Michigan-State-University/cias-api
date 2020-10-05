# frozen_string_literal: true

class V1::Problems::Index < BaseSerializer
  def cache_key
    "problems/#{@problems.count}-#{@problems.maximum(:updated_at)}"
  end

  def to_json
    {
      problems: collect_problems
    }
  end

  private

  def collect_problems
    @problems.map { |problem| V1::Problems::Show.new(problem: problem).to_json }
  end
end
