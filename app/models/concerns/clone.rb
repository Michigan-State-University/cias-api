# frozen_string_literal: true

module Clone
  include MetaOperations
  def clone(params)
    if params[:user_ids].present?
      problems = []
      user_ids = User.where(id: params[:user_ids]).limit_to_roles('researcher').pluck(:id)
      user_ids.each do |id|
        problems.push(
          "Clone::#{de_constantize_modulize_name.classify}".
            safe_constantize.
            new(self, user_id: id).
            execute
        )
      end
      problems
    else
      "Clone::#{de_constantize_modulize_name.classify}".
        safe_constantize.new(self).execute
    end
  end
end
