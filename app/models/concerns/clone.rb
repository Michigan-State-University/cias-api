# frozen_string_literal: true

module Clone
  include MetaOperations
  include InvitationInterface

  def clone(params: {}, clean_formulas: true, position: nil, hidden: false)
    if params[:emails].present?
      interventions = []

      existing_emails, non_existing_emails = split_emails_exist(params[:emails])
      invite_non_existing_users(non_existing_emails, true, [:researcher])

      user_ids = [existing_emails, non_existing_emails].map do |emails|
        User.where(email: emails).limit_to_roles(%w[e_intervention_admin researcher]).pluck(:id)
      end

      user_ids.zip(%i[existing non_existing]).each do |ids, type|
        ids.each do |id|
          interventions
            .push(
              [type,
               "Clone::#{de_constantize_modulize_name.classify}".
                 safe_constantize.
                 new(self, { user_id: id, clean_formulas: clean_formulas, position: position, hidden: hidden }).
                 execute]
            )
        end
      end
      interventions
    else
      "Clone::#{de_constantize_modulize_name.classify}".
        safe_constantize.new(self, clean_formulas: clean_formulas, position: position, params: params, hidden: hidden).execute
    end
  end
end
