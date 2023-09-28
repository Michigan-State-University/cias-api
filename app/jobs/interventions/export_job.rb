# frozen_string_literal: true

require 'json'

class Interventions::ExportJob < ApplicationJob
  def perform(user_id, intervention_id)
    @user = User.find(user_id)
    @intervention = Intervention.accessible_by(@user.ability).find(intervention_id)

    return unless @user.email_notification

    generate_file_and_send
  end

  private

  def generate_file_and_send
    file = Tempfile.new([@intervention.id, '.json'])
    file.write(intervention_data(@intervention))
    file.rewind

    ExportMailer.result(@user, @intervention.name, file.path).deliver_now
  ensure
    file.close
    file.unlink
  end

  def intervention_data(intervention)
    V1::Intervention::ExportData.call(intervention).to_json
  end
end
