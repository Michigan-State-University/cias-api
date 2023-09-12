# frozen_string_literal: true

module Clone
  include MetaOperations
  include InvitationInterface

  def clone(params: {}, clean_formulas: true, position: nil, hidden: false)
    emails = params[:emails]&.map(&:downcase)
    current_user_id = params[:user_id]

    if emails.blank?
      return clone_module.new(self, user_id: current_user_id, clean_formulas: clean_formulas, position: position, params: params, hidden: hidden).execute
    end

    cloned_elements = []

    _existing_emails, non_existing_emails = split_emails_exist(emails)
    invite_non_existing_users(non_existing_emails, true, [:researcher])

    user_ids = User.where(email: emails).limit_to_roles(%w[e_intervention_admin researcher]).pluck(:id)

    user_ids.each do |user_id|
      cloned_elements.push(
        clone_module.new(self, { user_id: user_id, clean_formulas: clean_formulas, position: position, hidden: hidden }).execute
      )
    end
    cloned_elements
  end

  private

  # returns the corresponding clone module (e.g. Intervention -> Clone::Intervention)
  def clone_module
    "Clone::#{de_constantize_modulize_name.classify}".safe_constantize
  end
end
