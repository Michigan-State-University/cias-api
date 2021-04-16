# frozen_string_literal: true

module MetaOperations
  extend ActiveSupport::Concern

  included do
    def de_constantize_modulize_name
      ctx_name = model_name.name
      deconst_ctx_name = ctx_name.deconstantize

      deconst_ctx_name.empty? ? ctx_name : deconst_ctx_name
    end
  end

  class FilesKeeper
    attr_accessor :add_to, :tmp_file
    attr_reader :stream, :options

    def initialize(**params)
      @stream = params[:stream]
      @add_to = params[:add_to]
      @options = params.except(:stream, :add_to)
    end

    def execute
      tmp_file
      attach_tmp_file
      delete_tmp_file
    end

    private

    def provide_time_zone
      options[:user]&.time_zone || ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')
    end

    def timestamp
      Time.current.in_time_zone(provide_time_zone).strftime(ENV.fetch('FILE_TIMESTAMP_NOTATION', '%m-%d-%Y_%H%M'))
    end

    def filename
      @filename ||= if options[:filename]
                      "#{options[:filename]}.#{options[:ext]}"
                    else
                      "#{timestamp}_#{add_to.name.parameterize.underscore[..12]}.#{options[:ext]}"
                    end
    end

    def tmp_file # rubocop:disable Lint/DuplicateMethods
      @tmp_file ||= File.open(Rails.root.join('tmp', filename), 'wb') do |file|
        file.write(stream)
        file.path
      end
    end

    def attach_tmp_file
      add_to.public_send(options[:macro]).attach(
        io: File.open(tmp_file),
        filename: filename,
        content_type: options[:type]
      )
      add_to.save!
    end

    def delete_tmp_file
      File.delete(tmp_file) if File.exist?(tmp_file)
    end
  end
end
