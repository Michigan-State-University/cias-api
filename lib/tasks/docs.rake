# frozen_string_literal: true

namespace :docs do
  desc 'Build API documentation'
  task build: :environment do
    Bundler.with_unbundled_env do
      Dir.chdir 'docs' do
        `bundle exec middleman build --clean`
      end
    end
  end
end
