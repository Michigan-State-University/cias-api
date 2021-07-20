# frozen_string_literal: true

class CsvJob::Answers < CsvJob
  include Rails.application.routes.url_helpers

  def perform(user_id, intervention_id, requested_at)
    user = User.find(user_id)

    intervention = Intervention.find(intervention_id)
    csv_content = intervention.export_answers_as(type: module_name)
    MetaOperations::FilesKeeper.new(
      stream: csv_content, add_to: intervention,
      macro: :reports, ext: :csv, type: 'text/csv', user: user
    ).execute

    return unless user.email_notification

    if intervention.draft?
      CsvMailer::Answers.csv_answers_preview(user, intervention, csv_content, requested_at).deliver_now
    else
      CsvMailer::Answers.csv_answers(user, intervention, csv_content, requested_at).deliver_now
    end
  end
end
