# frozen_string_literal: true

namespace :docs do
  desc 'Build API documentation'
  namespace :build do
    task v1: :environment do
      Bundler.with_unbundled_env do
        Dir.chdir 'docs/v1' do
          `bundle exec middleman build --clean`
        end
      end
    end
  end
end
