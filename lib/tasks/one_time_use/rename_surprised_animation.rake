# frozen_string_literal: true

namespace :questions do
  desc 'Rename suprised to surprised'
  task animation_rename: :environment do
    Question.find_each do |question|
      was_changed = false
      question.narrator['blocks'].each do |block|
        next unless block['animation'] == 'suprised'

        block['animation'] = 'surprised'
        p "Rename in question with id #{question.id}"
        was_changed = true
      end
      question.save! if was_changed
    end
  end
end
