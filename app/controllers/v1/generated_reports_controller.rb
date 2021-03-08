# frozen_string_literal: true

class V1::GeneratedReportsController < V1Controller
  include Pagy::Backend
  after_action { pagy_headers_merge(@pagy) if @pagy }

  def index
    authorize! :read, GeneratedReport

    set_limit
    set_order
    @pagy, @records = pagy(generated_reports_scope.order(created_at: @order), items: @limit)
    render json: serialized_response(@records)
  end

  private

  def generated_reports_scope
    GeneratedReportFinder.search(filter_params, current_v1_user)
  end

  def filter_params
    params.permit(:report_for)
  end

  def set_limit
    @limit = params[:limit].present? ? params[:limit].to_i : 7
  end

  def set_order
    @order = params[:order].present? ? params[:order] : "ASC"
    @order = "ASC" if not ["ASC", "DESC"].include?(@order.upcase)
  end
end
