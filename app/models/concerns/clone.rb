# frozen_string_literal: true

module Clone
  include MetaOperations
  include InvitationInterface

  def clone(params: {}, clean_formulas: true, position: nil, hidden: false)
    emails = params[:emails].map(&:downcase)
    if emails.present?
      interventions = []

      _existing_emails, non_existing_emails = split_emails_exist(emails)
      invite_non_existing_users(non_existing_emails, true, [:researcher])

      user_ids = User.where(email: emails).limit_to_roles(%w[e_intervention_admin researcher]).pluck(:id)

      user_ids.each do |user_id|
        interventions
          .push(
            "Clone::#{de_constantize_modulize_name.classify}".
              safe_constantize.
              new(self, { user_id: user_id, clean_formulas: clean_formulas, position: position, hidden: hidden }).
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
