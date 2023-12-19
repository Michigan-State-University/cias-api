# frozen_string_literal: true

require 'json'

class Interventions::ExportJob < ApplicationJob
  def perform(user_id, intervention_id)
    @user = User.find(user_id)
    @intervention = Intervention.accessible_by(@user.ability).find(intervention_id)

    generate_file
    return unless @user.email_notification

    notify_by_email
  end

  private

  def generate_file
    json_data = V1::Export::InterventionSerializer.new(@intervention).serializable_hash(include: '**')
    @intervention.exported_data.attach(io: StringIO.new(json_data.to_json), filename: "exported_#{@intervention.name}_#{Time.zone.now.strftime('%F-%T')}.json",
                                       content_type: 'application/json')
  end

  def notify_by_email
    ExportMailer.result(@user, @intervention).deliver_now
  end
end
