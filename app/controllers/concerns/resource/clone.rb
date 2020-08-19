# frozen_string_literal: true

module Resource::Clone
  extend ActiveSupport::Concern
  included do
    def clone
      cloned_resource = controller_name.
        classify.
        demodulize.
        safe_constantize.
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
        intervention: [],
        question: []
      }
    end
  end
end
