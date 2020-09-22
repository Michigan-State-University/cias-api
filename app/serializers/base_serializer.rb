# frozen_string_literal: true

class BaseSerializer
  Oj.default_options = { mode: :rails }

  def render
    Oj.dump(to_json)
  end

  def cached_render
    Rails.cache.fetch(cache_key) { render }
  end

  def to_json # rubocop:disable Lint/ToJSON
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  def cache_key
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
