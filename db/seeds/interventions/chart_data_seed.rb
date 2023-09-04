# frozen_string_literal: true

def main
  clear_table_cache

  organization
  session_fruits
  session_months
end

def researcher
  @researcher ||= User.new(
    first_name: 'Chart',
    last_name: 'Test',
    email: 'cias-team+charts_test_researcher@htdevelopers.com',
    terms: true, terms_confirmed_at: DateTime.now, confirmed_at: DateTime.now,
    password: "Aa1#{SecureRandom.base58(16)}!",
    roles: %i[researcher e_intervention_admin],
    organizable_id: organization.id, organizable_type: 'Organization'
  ).tap do |researcher|
    researcher.confirm
    researcher.save!

    EInterventionAdminOrganization.create!(
      user_id: researcher.id,
      organization_id: organization.id
    )
  end
end

def participants
  @participants ||= 200.times.each_with_object([]) do |index, array|
    participant = User.new(
      first_name: 'Participant',
      last_name: "Number #{index}",
      email: "participant_#{SecureRandom.base36(16)}@example.com",
      terms: true, terms_confirmed_at: DateTime.now,
      password: "Aa1#{SecureRandom.base58(16)}!",
      roles: [:participant]
    )

    participant.confirm
    participant.save!
    array << participant
  end
end

def intervention
  @intervention ||= Intervention.create!(
    name: 'Months and fruit - TEST INTERVENTION',
    user_id: researcher.id,
    status: :published,
    organization: organization
  )
end

def session_fruits
  return @session_fruits if @session_fruits.present?

  @session_fruits = Session.create!(
    intervention_id: intervention.id,
    name: 'Random fruit over a 1 year period'
  )

  question = Question::Single.create!(
    title: '<h2>Fruit Question</h2>',
    subtitle: '<p>What\'s your favorite fruit?</p>',
    question_group_id: QuestionGroup.create!(title: 'Test Group', session_id: @session_fruits.id).id,
    body: { 'data' => %w[Apple Banana Grape Pear].each.with_index(1).map do |fruit, index|
      { 'value' => index.to_s, 'payload' => "<p>#{fruit}</p>" }
    end, 'variable' => { 'name' => 'fruit' } }
  )

  participants.each do |participant|
    user_intervention = UserIntervention.create!(user_id: participant.id, intervention_id: intervention.id)

    finished_at = Random.rand(1..365).days.ago

    user_session = UserSession.create!(
      user_id: participant.id,
      session_id: @session_fruits.id,
      user_intervention_id: user_intervention.id,
      health_clinic_id: Random.rand(1..3) == 1 ? organization.health_clinics.first.id : organization.health_clinics.second.id
    )
    Answer::Single.create!(
      question_id: question.id,
      user_session_id: user_session.id,
      body: { 'data' => [{ 'value' => Random.rand(1..4), 'var' => 'fruit' }] }
    )
    user_session.update!(finished_at: finished_at)
  end
end

def session_months
  return @session_months if @session_months.present?

  @session_months = Session.create(
    intervention_id: intervention.id,
    name: 'Current over a 2 year period'
  )

  question = Question::Single.create!(
    title: '<h2>Fruit Question</h2>',
    subtitle: '<p>What\'s the current month?</p>',
    question_group_id: QuestionGroup.find_or_create_by!(title: 'Test Group', session_id: @session_months.id).id,
    body: { 'data' => %w[January February March April May June July August September October November December].each.with_index(1).map do |month, index|
      { 'value' => index.to_s, 'payload' => "<p>#{month}</p>" }
    end, 'variable' => { 'name' => 'month' } }
  )

  participants.each do |participant|
    user_intervention = UserIntervention.create!(user_id: participant.id, intervention_id: intervention.id)
    user_session = UserSession.create!(
      user_id: participant.id,
      session_id: @session_months.id,
      user_intervention_id: user_intervention.id,
      health_clinic_id: organization.health_clinics.first.id
    )

    finished_at = Random.rand(1..730).days.ago

    Answer::Single.create!(
      question_id: question.id,
      user_session_id: user_session.id,
      body: { 'data' => [{ 'value' => finished_at.month, 'var' => 'month' }] }
    )
    user_session.update!(finished_at: finished_at)
  end
end

def organization
  return @organization if @organization.present?

  @organization = Organization.create!(name: 'Chart Test Organization')
  health_system = HealthSystem.create!(name: 'Chart Test Health System', organization_id: @organization.id)
  HealthClinic.create!(name: 'Chart Test Clinic 1', health_system_id: health_system.id)
  HealthClinic.create!(name: 'Chart Test Clinic 2', health_system_id: health_system.id)
end

private

def clear_table_cache
  ActiveRecord::Base.connection.query_cache.clear
  (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
    table.classify.constantize.reset_column_information
  rescue StandardError
    nil
  end
end

ActiveRecord::Base.transaction { main }
