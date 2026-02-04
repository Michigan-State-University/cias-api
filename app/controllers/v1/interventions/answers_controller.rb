# frozen_string_literal: true

class V1::Interventions::AnswersController < V1Controller
  def index
    authorize! :get_protected_attachment, intervention

    requested_at = Time.current.in_time_zone(ENV.fetch('CSV_TIMESTAMP_TIME_ZONE', 'UTC'))
    day_format = ActiveSupport::Inflector.ordinalize(requested_at.day)
    formatted_requested_at = requested_at.strftime("%B #{day_format}, %Y %H:%M %Z")
    CsvJob::Answers.perform_later(
      current_v1_user.id,
      intervention_id,
      formatted_requested_at,
      period_of_time_params
    )
    render json: { message: I18n.t('interventions.answers.index.csv') }
  end

  def csv_attachment
    authorize! :get_protected_attachment, intervention

    head :no_content unless intervention.reports.attached?

    redirect_to(ENV.fetch('APP_HOSTNAME', nil) + Rails.application.routes.url_helpers.rails_blob_path(intervention.newest_report, only_path: true),
                allow_other_host: true)
  end

  private

  def intervention
    @intervention ||= Intervention.accessible_by(current_v1_user.ability).find(intervention_id)
  end

  def intervention_id
    params.require(:intervention_id)
  end

  def period_of_time_params
    params.permit(:start_datetime, :end_datetime, :timezone)
  end
end
