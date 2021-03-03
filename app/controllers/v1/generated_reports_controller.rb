# frozen_string_literal: true

class V1::GeneratedReportsController < V1Controller
  def index
    authorize! :read, GeneratedReport

    render json: serialized_response(generated_reports_scope)
  end

  private

  def generated_reports_scope
    GeneratedReportFinder.search(filter_params, current_v1_user)
  end

  def filter_params
    params.permit(:report_for)
  end
end
