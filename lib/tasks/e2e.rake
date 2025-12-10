# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc 'Creates E2E test users'
    task e2e: :environment do
      path = Rails.root.join('db/seeds/e2e.seeds.rb')
      if path.exist?
        file = File.open(path)
        load(file)
      else
        puts 'E2E seed file does not exist'
      end
    end
  end
end
