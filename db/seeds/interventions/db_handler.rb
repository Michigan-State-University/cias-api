# frozen_string_literal: true

require 'csv'

class DBHandler
  def initialize(file, headers)
    @file = file
    @headers = headers
    clear_file
  end

  def clear_file
    CSV.open(@file, 'wb') do |csv|
      csv << @headers
    end
  end

  def add_data(data)
    data.map do |data_value|
      data_value.delete('"') if instance_of? String
    end
    CSV.open(@file, 'a') do |csv|
      csv << data
    end
  end

  def save_to_db(table_name)
    sql = "COPY #{table_name}(#{@headers.to_s.sub('[', '').sub(']', '')}) FROM '#{@file}' DELIMITER ',' CSV HEADER;"

    ActiveRecord::Base.connection.exec_query(sql)
  end
end
