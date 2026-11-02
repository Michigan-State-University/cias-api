# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
# Also filters request params sent to Sentry.
Rails.application.config.filter_parameters += %i[
  password password_confirmation current_password
  first_name last_name email uid
  number
  body
  test_link_token
  dob sex zip mrn phone_type patient_id visit_id
  verification_code
]

# Twilio SMS webhook sender fields (From, FromZip, ...).
Rails.application.config.filter_parameters << /\AFrom/
