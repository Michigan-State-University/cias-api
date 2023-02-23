# frozen_string_literal: true

class V1::ShortLinks::ManagerService
  def initialize(object, short_links)
    @object = object
    @short_links = short_links
  end

  def self.call(object, short_links)
    new(object, short_links).call
  end

  attr_accessor :object, :short_links

  def call
    ActiveRecord::Base.transaction do
      object.remove_short_links
      add_new_short_links!
    end
  end

  private

  def add_new_short_links!
    new_short_links = short_links.map do |short_link_params|
      ShortLink.new(short_link_params.merge(linkable: object)) if short_link_params['name'].present?
    end

    check_new_short_links(new_short_links)

    new_short_links.each(&:save!)
  end

  def check_new_short_links(array_of_short_links)
    invalid_names = array_of_short_links.filter_map do |short_link|
      short_link.valid? ? nil : short_link.name
    end

    if invalid_names.any?
      raise ComplexException.new(I18n.t('activerecord.errors.models.short_link.attributes.name.already_exists'),
                                 { taken_names: invalid_names })
    end
  end
end
