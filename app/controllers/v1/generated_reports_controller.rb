# frozen_string_literal: true

class V1::GeneratedReportsController < V1Controller
  include Pagy::Backend
  after_action { pagy_headers_merge(@pagy) if @pagy }

  def index
    authorize! :read, GeneratedReport

    collection = generated_reports_scope
    paginated_collection = paginate(collection.order(created_at: order), params)
    response = serialized_hash(
      paginated_collection,
    )
    response = response.merge(reports_size: collection.size)
    
    render json: response
  end

  private

  def generated_reports_scope
    GeneratedReportFinder.search(filter_params, current_v1_user)
  end

  def filter_params
    params.permit(:report_for)
  end

  def order
    order = params[:order].present? ? params[:order] : "ASC"
    order = "ASC" if not order.casecmp?("DESC")
    order
  end
end
