# frozen_string_literal: true

class V1::DownloadedReportsController < V1Controller
  def create
    report = DownloadedReport.find_or_create_by!(
      user_id: current_v1_user.id,
      generated_report_id: report_id_param
    )
    render json: serialized_response(report), status: :ok
  end

  private

  def report_id_param
    params.require(:report_id)
  end
end
