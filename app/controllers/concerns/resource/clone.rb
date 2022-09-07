# frozen_string_literal: true

module Resource::Clone
  extend ActiveSupport::Concern
  included do
    def clone
      authorize! :update, model_constant

      resource = model_constant.find(params[:id])

      return head :forbidden unless resource.ability_to_clone?

      cloned_resource = resource.
        clone(params: clone_params)
      render json: serialized_response(cloned_resource), status: :created
    end
  end

  private

  def clone_params
    key = controller_name.singularize.to_sym
    params.fetch(key, {}).permit(*to_permit[key])
  end

  def to_permit
    @to_permit ||= {
      intervention: [{ user_ids: [] }],
      session: [],
      question: [],
      sms_plan: []
    }
  end
end
