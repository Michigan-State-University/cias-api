# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_participants_and_researchers(participant_num, researcher_num)
  users_settings = [
    { role: 'participant', num_to_create: participant_num },
    { role: 'researcher', num_to_create: researcher_num }
  ]

  users_settings.each do |users|
    users[:num_to_create].times do |index|
      create_user(users[:role])
      p "#{index + 1}/#{users[:num_to_create]} #{users[:role]}s created"
    end
  end
end
# rubocop:enable Rails/Output

def create_user(roles, email = nil, password = nil)
  roles = Array(roles)
  create(
    :user,
    :confirmed,
    email: email || "#{Time.current.to_i}_#{SecureRandom.hex(10)}@#{roles[0]}.true",
    password: password || "#{Faker::Alphanumeric.alphanumeric(number: 10).capitalize}!@#",
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    roles: roles
  )
end

def assign_variable!(question)
  position = question.position
  case question.type
  when 'Question::Multiple'
    question.body['data'].each_with_index do |row, index|
      row['variable']['name'] = create_variable(position, index)
    end
  when 'Question::Grid'
    question.body['data'][0]['payload']['rows'].each_with_index do |row, index|
      row['variable']['name'] = create_variable(position, index)
    end
  else
    question.body['variable']['name'] = create_variable(position) unless question.question_variables.empty?
  end
  question.save!
end

def create_variable(position, position_extra = nil)
  var = "var_#{position}"
  var += "_#{position_extra}" if position_extra
  var
end

def assign_data_to_answer(answer, question)
  var_name = question.question_variables&.sample
  data = []
  case question.type
  when 'Question::Date'
    value = Faker::Date.birthday(min_age: 0, max_age: 1)
  when 'Question::FreeResponse'
    value = Faker::Food.dish
  when 'Question::Currency'
    value = "#{Faker::Currency.code} #{Faker::Number.decimal(l_digits: 3)}"
  else
    value = rand(1..5).to_s
  end
  data << { var: var_name, value: value }

  if ['Question::Grid', 'Question::Multiple'].include?(question.type)
    data = question.question_variables.map { |var| { 'var' => var, 'value' => rand(1..5).to_s } }
  end

  add_data_to_answer_body(answer, data)
end

def add_data_to_answer_body(answer, data)
  answer.body = {
    data: data
  }
  answer.save!
end

def create_branching(question, paths, max_branches)
  question.formulas = [{ 'payload' => '1', 'patterns' => [] }]
  (1..max_branches).each do |index|
    path = paths.sample
    paths.delete(path)
    break if path.blank?

    question.formulas.first['patterns'] << { 'match' => "=#{index}",
                                             'target' => [{ 'id' => path['id'], 'type' => path['type'], 'probability' => '100' }] }
    question.save!
  end
end

def branchable_question?(current_question, branch_question)
  current_question.position < branch_question.position
end

def q_groups_from_intervention(exclude = {})
  Intervention.where.not(exclude).flat_map(&:sessions).flat_map(&:question_groups)
end
