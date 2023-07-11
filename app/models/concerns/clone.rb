# frozen_string_literal: true

module Clone
  include MetaOperations

  def clone(params: {}, clean_formulas: true, position: nil, hidden: false)
    if params[:emails].present?
      interventions = []
      user_ids = User.where(email: params[:emails]).limit_to_roles(%w[e_intervention_admin researcher]).pluck(:id)
      user_ids.each do |id|
        interventions.push(
          "Clone::#{de_constantize_modulize_name.classify}".
            safe_constantize.
            new(self, { user_id: id, clean_formulas: clean_formulas, position: position, hidden: hidden }).
            execute
        )
      end
      interventions
    else
      "Clone::#{de_constantize_modulize_name.classify}".
        safe_constantize.new(self, clean_formulas: clean_formulas, position: position, params: params, hidden: hidden).execute
    end
  end
end
