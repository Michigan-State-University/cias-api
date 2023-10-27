# frozen_string_literal: true

require 'json'

class Interventions::ExportJob < ApplicationJob
  def perform(user_id, intervention_id)
    profile_memory do
      profile_time do
        profile_gc do

          @user = User.find(user_id)
          @intervention = Intervention.accessible_by(@user.ability).find(intervention_id)

          return unless @user.email_notification

          generate_file_and_send

        end
      end
    end
  end

  private

  def generate_file_and_send
    # file = Tempfile.new([@intervention.id, '.json'])
    # file.write(intervention_data(@intervention))
    # file.rewind
    # require 'pry'; binding.pry
    # file = generated_file
    # @intervention.exported_data.attach(io: file, filename: "exported_#{@intervention.name}_#{Time.now.strftime("%F-%T")}.json", content_type: "application/json")
    # ExportMailer.result(@user, @intervention.name, file.path).deliver_now

    json_data = V1::Export::InterventionSerializer.new(@intervention).serializable_hash(include: '**')
    @intervention.exported_data.attach(io:  StringIO.new(json_data.to_json), filename: "exported_#{@intervention.name}_#{Time.now.strftime("%F-%T")}.json", content_type: "application/json")
  ensure
    # file.close
    # file.unlink
  end

  def intervention_data(intervention)
    V1::Intervention::ExportData.call(intervention).to_json
  end

  def generated_file
    V1::Intervention::ExportData.new(@intervention).generate_file
  end


  def profile_memory
    memory_usage_before = `ps -o rss= -p #{Process.pid}`.to_i
    yield
    memory_usage_after = `ps -o rss= -p #{Process.pid}`.to_i

    used_memory = ((memory_usage_after - memory_usage_before) / 1024.0).round(2)
    puts "Memory usage: #{used_memory} MB"
  end

  def profile_time
    time_elapsed = Benchmark.realtime do
      yield
    end

    puts "Time: #{time_elapsed.round(2)} seconds"
  end

  def profile_gc
    GC.start
    before = GC.stat(:total_freed_objects)
    yield
    GC.start
    after = GC.stat(:total_freed_objects)

    puts "Objects Freed: #{after - before}"
  end
end
