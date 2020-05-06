# frozen_string_literal: true

admin1 = User.new(first_name: 'admin', last_name: '1', login: 'admin', roles: %w[administrator], email: "admin@#{ENV['DOMAIN_NAME']}", password: 'qwerty1234')
admin1.confirm
admin1.save
