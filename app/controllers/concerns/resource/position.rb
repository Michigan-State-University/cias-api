# frozen_string_literal: true

module Resource::Position
  extend ActiveSupport::Concern
  included do
    def position
      authorize! :update, model_constant

      SqlQuery.new(
        'resource/position_bulk_update',
        values: position_params[:position],
        table: controller_name
      ).execute
      invalidate_cache(send("#{controller_name}_scope"))
      render_json(**response_scope, path: "v1/#{controller_name}", action: :index)
    end
  end

  private

  def position_params
    params.require(controller_name.classify.underscore.to_sym).permit(position: %i[id position])
  end

  def response_scope
    { controller_name.to_s => send("#{controller_name}_scope") }
  end
end
