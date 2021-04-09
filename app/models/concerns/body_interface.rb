# frozen_string_literal: true

module BodyInterface
  extend ActiveSupport::Concern
  include BodyInterface::Guard

  included do
    before_save :guard_protection
  end

  def body_data
    data_container['data']
  end

  def body_variable
    data_container['variable']
  end

  private

  def data_container
    self.class.superclass.name == 'Answer' ? decrypted_body : body
  end
end
