# frozen_string_literal: true

module Resource::Position
  extend ActiveSupport::Concern
  included do
    def position
      SqlQuery.new(
        'resource/position_bulk_update',
        values: position_params[:position],
        table: controller_name
      ).execute
      invalidate_cache(send("#{controller_name}_scope"))
      render json: serialized_response(send("#{controller_name}_scope"))
    end
  end

  private

  def position_params
    params.require(controller_name.classify.downcase.to_sym).permit(position: %i[id position])
  end
end
