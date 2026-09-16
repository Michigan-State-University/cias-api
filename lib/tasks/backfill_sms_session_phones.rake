# frozen_string_literal: true

namespace :sms_sessions do
  desc 'Backfill phone number data for existing SMS user sessions from user phone records'
  task backfill_phones: :environment do
    puts 'Starting backfill of SMS session phone data...'

    total_count = 0
    updated_count = 0
    skipped_count = 0
    no_phone_count = 0

    UserSession::Sms.where(sms_phone_prefix: nil).find_each do |user_session|
      total_count += 1

      user = user_session.user
      phone = user&.phone

      if phone.blank?
        no_phone_count += 1
        puts "  User session #{user_session.id}: No phone record found for user #{user&.id}"
        next
      end

      if phone.prefix.blank? || phone.number.blank?
        skipped_count += 1
        puts "  User session #{user_session.id}: Phone record has incomplete data (prefix: #{phone.prefix.present?}, number: #{phone.number.present?})"
        next
      end

      user_session.update!(
        sms_phone_prefix: phone.prefix,
        sms_phone_number: phone.number
      )
      updated_count += 1

      puts "  User session #{user_session.id}: Updated with phone #{phone.prefix}#{phone.number}"
    rescue StandardError => e
      puts "  User session #{user_session.id}: Error - #{e.message}"
    end

    puts "\nBackfill complete!"
    puts "  Total SMS sessions processed: #{total_count}"
    puts "  Successfully updated: #{updated_count}"
    puts "  Skipped (incomplete phone data): #{skipped_count}"
    puts "  No phone record found: #{no_phone_count}"
  end
end
