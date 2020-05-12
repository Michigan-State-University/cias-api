# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc 'Loads the seed fake data from db/seeds/fake.rb'
    task fake: :environment do
      path = Rails.root.join('db/seeds/fake.rb')
      if path.exist?
        file = File.open(path)
        load(file)
      else
        puts 'File with fake data does not exist'
      end
    end
  end
end
