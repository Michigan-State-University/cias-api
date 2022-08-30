# frozen_string_literal: true

require 'csv'

class DBHandler
  def initialize(file)
    @file = file
    @data = []
  end

  def new_table_with_default_values(table_name, columns_hash)
    new_table(table_name, columns_hash)
    default_values
  end

  def new_table(table_name, columns_hash)
    @table_name = table_name
    @headers = columns_hash.keys.map(&:to_s)
    @data_types = @headers.zip(columns_hash.values.map(&:type)).to_h
    clear_file
  end

  def default_values
    default_values = {}
    @headers.each do |column|
      data_type = @data_types[column]
      case data_type
      when :uuid
        value = Faker::Internet.unique.uuid
      when :string
        value = ''
      when :datetime
        value = Time.zone.now.to_s
      when :integer
        value = 0
      when :boolean
        value = false
      else
        value = nil
      end
      default_values[column.to_sym] = value
    end
    default_values
  end

  def store_data(data)
    data[:id] = Faker::Internet.unique.uuid
    @data << data.values
  end

  def save_data_to_db
    @data.each do |data_row|
      data_row.each do |data_value|
        data_value.delete('"') if instance_of? String

        next unless data_value.instance_of? Hash

        data_value.each do |k, v|
          data_value[k] = v.to_s.gsub(/\r\n?/, '').delete("\n").delete("\r")
        end
      end
    end

    CSV.open(@file, 'a') do |csv|
      @data.each { |column| csv << column }
    end

    @data = []

    sql_table_headers = @headers.to_s.sub('[', '').sub(']', '')

    sql = "COPY #{@table_name}(#{sql_table_headers}) FROM '#{@file}' DELIMITER ',' CSV HEADER;"
    ActiveRecord::Base.connection.exec_query(sql)
  end

  private

  def clear_file
    CSV.open(@file, 'wb') do |csv|
      csv << @headers
    end
  end
end
