# frozen_string_literal: true

module SmsHelper
  include Rails.application.routes.url_helpers

  def can_run_plan?(plan)
    return false if plan.is_used_formula.blank? && plan.no_formula_text.blank?
    return false if plan.is_used_formula && (plan.formula.blank? || plan.variants.empty?)

    true
  end

  def sms_content(plan)
    plan.is_used_formula ? matched_variant(plan)&.content : plan.no_formula_text
  end

  def matched_variant(plan)
    all_var_values = V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
    V1::SmsPlans::CalculateMatchedVariant.call(plan.formula, plan.variants, all_var_values)
  end

  def attachment_url(plan)
    attachment = if plan.is_used_formula
                   matched_variant(plan).attachment
                 else
                   plan.no_formula_attachment
                 end
    url_for(attachment) if attachment.attached?
  end

  def insert_name_into_variant(content)
    content.gsub!('.:name:.', name_variable.presence || 'Participant')
  end

  def insert_variables_into_variant(content)
    insert_name_into_variant(content)

    user_intervention_answer_vars.each do |variable, value|
      content.gsub!(".:#{variable}:.", value.present? ? value.to_s : 'Unknown')
    end
    content
  end

  def insert_links_into_variant(content, plan)
    plan.sms_links.each do |sms_link|
      sms_links_user = sms_link.sms_links_users.create!(user: user)
      content.gsub!("::#{sms_link.variable}::", "#{ENV.fetch('WEB_URL')}/link/#{sms_links_user.slug}")
    end

    content
  end

  def name_variable
    @name_variable ||= Answer::Name.find_by(
      user_session_id: user_session.id
    )&.body_data&.first&.dig('value').presence&.dig('name')
  end

  def user_intervention_service
    @user_intervention_service ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id)
  end

  def user_intervention_answer_vars
    user_intervention_service.var_values
  end

  def number_days
    {
      'once_a_day' => 1,
      'once_a_week' => 7,
      'once_a_month' => 30
    }
  end

  def send_sms(start_time, content, attachment_url = nil)
    SmsPlans::SendSmsJob.set(wait_until: start_time).perform_later(user.phone.full_number, content, attachment_url, user.id, false, user_session.session_id)
  end

  def phone
    @phone ||= user.phone
  end

  def user
    @user ||= user_session.user
  end

  def phone_answer
    return @phone_answer if defined?(@phone_answer)

    @phone_answer = user_session.answers.find_by(type: 'Answer::Phone')
  end

  def session
    @session ||= user_session.session
  end

  def timezone
    timezone_defined_by_user = value_provided_by_the_user.present? ? value_provided_by_the_user['timezone'].to_s : ''
    ActiveSupport::TimeZone[timezone_defined_by_user].present? ? timezone_defined_by_user : Phonelib.parse(phone.full_number).timezone
  end

  def time_ranges_defined_by_user
    @time_ranges_defined_by_user ||= if value_provided_by_the_user.present?
                                       value_provided_by_the_user['time_ranges']
                                     else
                                       ''
                                     end
  end

  def value_provided_by_the_user
    @value_provided_by_the_user ||= phone_answer&.migrated_body&.dig('data', 0, 'value')
  end

  def random_time
    time_range = if time_ranges_defined_by_user.blank?
                   TimeRange.default_range
                 else
                   time_ranges_defined_by_user.sample
                 end

    minutes_in_range = (time_range['to'].to_f - time_range['from'].to_f) * 60
    random_minutes = rand(minutes_in_range)
    {
      hour: time_range['from'].to_i + (random_minutes / 60).to_i,
      min: random_minutes % 60
    }
  end
end
