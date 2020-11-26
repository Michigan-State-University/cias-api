# frozen_string_literal: true

class V1::Sessions::Index < BaseSerializer
  def cache_key
    "sessions/#{sessions.count}-#{sessions.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    {
      sessions: collect_sessions
    }
  end

  private

  attr_reader :sessions

  def collect_sessions
    sessions.map do |session|
      V1::Sessions::Show.new(session: session).to_json
    end
  end
end
