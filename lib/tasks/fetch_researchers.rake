# frozen_string_literal: true

namespace :users do
  desc 'Fetch list of all researchers at once'
  task fetch_researchers: :environment do
    p '-------LIST OF RESEARCHERS-------'
    p User.researchers.map(&:email)
    p '---------------END---------------'
  end
end
