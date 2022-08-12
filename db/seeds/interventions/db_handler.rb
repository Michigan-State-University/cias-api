# frozen_string_literal: true

require 'csv'

class DBHandler
  def initialize(file)
    @file = file
  end

  def new_table(table_name, headers)
    @table_name = table_name
    @headers = headers
    clear_file
  end

  def save_data_to_db(data)
    data.each do |data_row|
      data_row.each do |data_value|
        data_value.delete('"') if instance_of? String

        next unless data_value.instance_of? Hash

        data_value.each do |k, v|
          data_value[k] = v.to_s.gsub(/\r\n?/, '').delete("\n").delete("\r")
        end
      end
    end

    CSV.open(@file, 'a') do |csv|
      data.each { |column| csv << column }
    end

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
