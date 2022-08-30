# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_users(user_num)
  (user_num - 1).times do |index|
    create_user(%w[participant])
    p "#{index + 1}/#{user_num} users created"
  end

  researcher = create_user(%w[researcher admin])
  p "#{user_num}/#{user_num} users created"
  p 'Successfully added Users to database!'

  researcher
end

# rubocop:enable Rails/Output

private

def create_user(roles)
  create(
    :user,
    :confirmed,
    email: "#{Time.current.to_i}_#{SecureRandom.hex(10)}@#{roles[0]}.true",
    password: 'Password1!',
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    roles: roles
  )
end
