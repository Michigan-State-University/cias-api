# frozen_string_literal: true

module Resource::Clone
  extend ActiveSupport::Concern
  included do
    def clone
      authorize! :update, model_constant
      cloned_resource = model_constant.
        find(params[:id]).
        clone(params: clone_params)
      render json: serialized_response(cloned_resource), status: :created
    end


    # def clone
    #   authorize! :update, model_constant
    #
    #   CloneJob.perform_later(current_v1_user, model_constant, params[:id], clone_params)
    #
    #   render status: :ok
    # end
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
