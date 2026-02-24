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
      render json: serialized_response(response_scope["#{controller_name.classify.underscore}s"])
    end
  end

  private

  def position_params
    params.expect(controller_name.classify.underscore.to_sym => [position: %i[id position]])
  end

  def response_scope
    { controller_name.to_s => send(:"#{controller_name}_scope") }
  end
end
