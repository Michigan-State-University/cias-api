# frozen_string_literal: true

class BaseSerializer
  Oj.default_options = { mode: :rails }

  def initialize(obj)
    obj.each_pair do |key, value|
      instance_variable_set(:"@#{key}", value)
    end
  end

  def render
    Oj.generate(to_json)
  end

  def cached_render
    Rails.cache.fetch(cache_key) { render }
  end

  def to_json
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def cache_key
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  protected

  def url_for_image(resource, attribute = :image)
    image = resource.public_send(attribute)

    polymorphic_url(image) if image.attached?
  end
end
