# frozen_string_literal: true

module Resource::Clone
  extend ActiveSupport::Concern
  included do
    def clone
      authorize! :update, model_constant
      cloned_resource = model_constant.
        find(params[:id]).
        clone(clone_params)
      render json: serialized_response(cloned_resource), status: :created
    end
  end

  private

  def clone_params
    key = controller_name.singularize.to_sym
    params.fetch(key, {}).permit(*to_permit[key])
  end

  def to_permit
    @to_permit ||= begin
      {
        problem: [{ user_ids: [] }],
        session: [],
        question: []
      }
    end
  end
end
