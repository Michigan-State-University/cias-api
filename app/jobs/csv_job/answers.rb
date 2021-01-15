# frozen_string_literal: true

class CsvJob::Answers < CsvJob
  include Rails.application.routes.url_helpers

  def perform(user_id, intervention_id)
    user = User.find(user_id)
    intervention = Intervention.find(intervention_id)
    MetaOperations::FilesKeeper.new(
      stream: intervention.export_answers_as(type: module_name), add_to: intervention,
      macro: :reports, ext: :csv, type: 'text/csv', user: user
    ).execute
    blob_path = rails_blob_path(intervention.reports.blobs.last, only_path: true)
    CsvMailer::Answers.csv_answers(user, intervention, blob_path).deliver_now
  end
end
