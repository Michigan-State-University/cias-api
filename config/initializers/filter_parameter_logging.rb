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
  slug token url phone
  dob sex zip mrn phone_type patient_id visit_id
  verification_code
]

# Twilio SMS webhook sender/recipient fields (From, To, FromZip, ToCity, ...).
twilio_phone_and_location_params = /\A(From|To)(?:[A-Z]|\z)/

Rails.application.config.filter_parameters << twilio_phone_and_location_params
