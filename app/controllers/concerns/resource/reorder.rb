# frozen_string_literal: true

module Resource::Reorder
  extend ActiveSupport::Concern

  included do
    def move
      authorize! :update, reorder_scope_class

      return head :forbidden unless ability_to_update?

      V1::ReorderService.call(reorder_data_scope, reorder_params[:position])

      render json: reorder_response, status: :ok
    end
  end

  protected

  def reorder_params
    params.require(controller_name.singularize.to_sym).permit(position: %i[id position])
  end

  def reorder_response
    raise NotImplementedError, "Including class did not implement #{__method__} method"
  end

  def reorder_data_scope
    raise NotImplementedError, "Including class did not implement #{__method__} method"
  end

  def ability_to_update?
    raise NotImplementedError, "Including class did not implement #{__method__} method"
  end

  def reorder_scope_class
    reorder_data_scope.klass
  end
end
