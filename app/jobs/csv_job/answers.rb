# frozen_string_literal: true

class CsvJob::Answers < CsvJob
  include Rails.application.routes.url_helpers

  def perform(user_id, intervention_id, requested_at, period_of_time_params = {})
    user = User.find(user_id)
    start_datetime = safe_parse(period_of_time_params[:start_datetime], period_of_time_params[:timezone])
    end_datetime = safe_parse(period_of_time_params[:end_datetime], period_of_time_params[:timezone])
    period_ot_time = define_period_of_time(start_datetime, end_datetime)
    intervention = Intervention.find(intervention_id)
    csv_content = intervention.export_answers_as(type: module_name, period: period_ot_time)
    MetaOperations::FilesKeeper.new(
      stream: csv_content, add_to: intervention,
      macro: :reports, ext: :csv, type: 'text/csv', user: user, suffix: suffix_filename(start_datetime, end_datetime)
    ).execute

    return unless user.email_notification

    if intervention.draft?
      CsvMailer::Answers.csv_answers_preview(user, intervention, csv_content, requested_at).deliver_now
    else
      CsvMailer::Answers.csv_answers(user, intervention, requested_at).deliver_now
    end
  end

  private

  def define_period_of_time(start_datetime, end_datetime)
    if start_datetime.present? && end_datetime.present?
      start_datetime..end_datetime
    elsif start_datetime.present?
      start_datetime...
    elsif end_datetime.present?
      Time.zone.at(0)..end_datetime

    end
  end

  def suffix_filename(start_datetime, end_datetime)
    if start_datetime.present? && end_datetime.present?
      "#{start_datetime.strftime('%Y-%m-%d-%H-%M')}_to_#{end_datetime.strftime('%Y-%m-%d-%H-%M')}"
    elsif start_datetime.present?
      "from_#{start_datetime.strftime('%Y-%m-%d-%H-%M')}_onwards"
    elsif end_datetime.present?
      "up_to_#{end_datetime.strftime('%Y-%m-%d-%H-%M')}"
    else
      'full_export'
    end
  end

  def safe_parse(datetime_as_string, timezone = 'UTC')
    return nil if datetime_as_string.blank?

    datetime_as_string.to_datetime.in_time_zone(timezone)
  rescue StandardError
    nil
  end
end
