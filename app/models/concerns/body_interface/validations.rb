# frozen_string_literal: true

module BodyInterface::Validations
  def body_has_one_element
    return if body_data.size.eql?(1)

    throw_err('collection can contain only one item')
  end

  def body_has_at_least_one_element
    return unless body_data.empty?

    throw_err('collection is empty')
  end

  private

  def throw_err(msg, exc = ActiveRecord::RecordInvalid)
    errors.add(:body, msg)
    raise exc, self
  end
end
