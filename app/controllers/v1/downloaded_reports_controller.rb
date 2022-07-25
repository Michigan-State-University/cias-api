# frozen_string_literal: true

class V1::DownloadedReportsController < V1Controller
  def create
    authorize! :create, DownloadedReport
    if already_downloaded?
      render json: { message: 'Report was already marked as downloaded' }.to_json, status: :unprocessable_entity
    else
      report_status = DownloadedReport.create!(
        user_id: current_v1_user.id,
        generated_report_id: report_id_param,
        downloaded: true
      )

      render json: serialized_response(report_status), status: :created
    end
  end

  private

  def already_downloaded?
    !DownloadedReport.find_by(user_id: current_v1_user.id, generated_report_id: report_id_param).nil?
  end

  def report_id_param
    params.require(:report_id)
  end
end
