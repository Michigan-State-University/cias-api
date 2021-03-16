# frozen_string_literal: true

class V1::Interventions::Show < BaseSerializer
  def cache_key
    "intervention/#{@intervention.id}-#{@intervention.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @intervention.id,
      name: @intervention.name,
      status: @intervention.status,
      shared_to: @intervention.shared_to,
      created_at: @intervention.created_at,
      updated_at: @intervention.updated_at,
      published_at: @intervention.published_at,
      csv_link: csv_link,
      logo_url: url_for_image(@intervention, :logo),
      csv_generated_at: csv_generated_at,
      user: {
        email: @intervention.user.email,
        first_name: @intervention.user.first_name,
        last_name: @intervention.user.last_name
      },
      sessions_size: @intervention.sessions.size
    }
  end

  private

  def csv_link
    newest_csv_link if @intervention.reports.attached?
  end

  def csv_generated_at
    @intervention.newest_report.created_at if @intervention.reports.attached?
  end

  def newest_csv_link
    ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(@intervention.newest_report, only_path: true)
  end
end
