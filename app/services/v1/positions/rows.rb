# frozen_string_literal: true

class V1::Positions::Rows
  POSITION_TYPE = ActiveModel::Type::Integer.new

  def initialize(values, uuid_keys: %i[id])
    invalid! unless values.is_a?(Array)

    @uuid_keys = uuid_keys
    @rows = values.map { |value| parse(value) }
    invalid! if ids.uniq.size != ids.size
  end

  def ids
    column(:id)
  end

  def column(key)
    @rows.pluck(key)
  end

  def mapping(key)
    @rows.to_h { |row| [row[:id], row[key]] }
  end

  private

  def parse(value)
    @uuid_keys.index_with { |key| uuid(value[key]) }.merge(position: position(value[:position]))
  end

  def uuid(value)
    uuid_type.cast(value) || invalid!
  end

  def position(value)
    number = Integer(value.to_s, 10, exception: false)
    invalid! unless number && POSITION_TYPE.serializable?(number)

    number
  end

  def uuid_type
    @uuid_type ||= ActiveRecord::Type.lookup(:uuid, adapter: :postgresql)
  end

  def invalid!
    raise ComplexException.new(I18n.t('exceptions.invalid_positions'), {}, :unprocessable_content)
  end
end
