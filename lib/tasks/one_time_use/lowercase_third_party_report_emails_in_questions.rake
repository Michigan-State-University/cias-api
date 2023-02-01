# frozen_string_literal: true

namespace :one_time_use do
  desc 'Converts existing emails in third party questions to lowercase to avoid future errors'

  task lowercase_third_party_report_emails_in_questions: :environment do
    questions_fixed, total_entries_fixed = 0, 0
    p 'STARTING THE EMAIL FIXING PROCESS'
    questions_count = Question::ThirdParty.count
    Question::ThirdParty.find_each.with_index do |question, index|
      fixed_in_question = 0
      question.body['data'].each do |data|
        if /[[:upper:]]/.match?(data['value'])
          data['value'] = data['value'].downcase
          fixed_in_question += 1
        end
      end

      if fixed_in_question > 0
        questions_fixed += 1
      end

      total_entries_fixed += fixed_in_question

      question.save!

      p "FINISHED PROCESSING #{index + 1}/#{questions_count} QUESTIONS"
    end

    p "PROCESSING DONE; #{questions_fixed} QUESTIONS FIXED WITH A TOTAL OF #{total_entries_fixed} EMAIL ENTRIES TOUCHED"
  end
end
