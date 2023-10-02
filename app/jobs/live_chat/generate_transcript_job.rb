# frozen_string_literal: true

class LiveChat::GenerateTranscriptJob < ApplicationJob
  def perform(obj_id, model_class, file_attach_point, intervention_name, user_id)
    user = User.find(user_id)
    object = model_class.find(obj_id)

    object_name = model_class.name.demodulize
    service_class = "V1::LiveChat::Conversations::GenerateTranscript::#{object_name}".safe_constantize
    result = service_class.call(object)

    MetaOperations::FilesKeeper.new(
      stream: result.to_csv, add_to: object,
      macro: file_attach_point, ext: :csv, type: 'text/csv',
      filename: transcript_file_name(intervention_name)
    ).execute

    V1::Notifications::TranscriptReady.call(object, user, intervention_name)

    return unless user.email_notification

    LiveChat::TranscriptMailer.send("#{object_name.downcase}_transcript", user.email, object).deliver_now
  end

  private

  def transcript_file_name(base_name)
    timestamp = Time.current.in_time_zone(ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')).
      strftime(ENV.fetch('FILE_TIMESTAMP_NOTATION', '%m-%d-%Y_%H%M'))
    "#{timestamp}_#{base_name.parameterize.underscore[..12]}"
  end
end
