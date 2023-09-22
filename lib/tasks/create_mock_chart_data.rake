# frozen_string_literal: true

desc 'Creates mock data suitable for testing charts (the answers are distributed in time)'

namespace :db do
  namespace :seed do
    desc 'Loads the seed fake data from db/seeds/interventions/chart_data_seed.rb'
    task chart_data: :environment do
      path = Rails.root.join('db/seeds/interventions/chart_data_seed.rb')
      if path.exist?
        file = File.open(path)
        load(file)
      else
        puts 'File with fake data does not exist'
      end
    end
  end
end
