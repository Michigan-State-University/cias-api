# frozen_string_literal: true

class V1::GeneratedReportsController < V1Controller
  def index
    authorize! :read, GeneratedReport

    collection = generated_reports_scope.order(created_at: order)
    paginated_collection = paginate(collection, params)
    render json: serialized_hash(paginated_collection, controller_name.classify,
                                 params: { user_id: current_v1_user.id }).merge(reports_size: collection.size)
  end

  private

  def generated_reports_scope
    GeneratedReportFinder.search(filter_params, current_v1_user).includes(:downloaded_reports)
  end

  def filter_params
    params.permit(:session_id, report_for: [])
  end

  def order
    order = params[:order].presence || 'ASC'
    order.casecmp?('DESC') ? order : 'ASC'
  end
end
