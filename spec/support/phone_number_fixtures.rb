# frozen_string_literal: true

module PhoneNumberFixtures
  US_MAIN = { iso: 'US', prefix: '+1', number: '2015550123' }.freeze
  US_OTHER = { iso: 'US', prefix: '+1', number: '2015550124' }.freeze
  PL_MOBILE = { iso: 'PL', prefix: '+48', number: '512345678' }.freeze
  PL_LANDLINE = { iso: 'PL', prefix: '+48', number: '123456789' }.freeze
  PL_PREMIUM = { iso: 'PL', prefix: '+48', number: '701123456' }.freeze
  US_PREMIUM = { iso: 'US', prefix: '+1', number: '9002221234' }.freeze
  US_TOLL_FREE = { iso: 'US', prefix: '+1', number: '8005550123' }.freeze
  GB_MOBILE = { iso: 'GB', prefix: '+44', number: '7400123456' }.freeze
  FR_MOBILE = { iso: 'FR', prefix: '+33', number: '612345678' }.freeze
  DE_MOBILE = { iso: 'DE', prefix: '+49', number: '15112345678' }.freeze
  PR_MOBILE = { iso: 'PR', prefix: '+1', number: '7875551234' }.freeze
  JM_MOBILE = { iso: 'JM', prefix: '+1', number: '8765551234' }.freeze
  DO_MOBILE = { iso: 'DO', prefix: '+1', number: '8095551234' }.freeze

  NANP_SHARED_COUNTRY_CODE = {
    'a PR mobile on NPA 787' => PR_MOBILE,
    'a PR mobile on NPA 939' => { iso: 'PR', prefix: '+1', number: '9392001234' },
    'a JM mobile on NPA 876' => JM_MOBILE,
    'a JM mobile on NPA 658' => { iso: 'JM', prefix: '+1', number: '6582001234' },
    'a DO mobile on NPA 809' => DO_MOBILE,
    'a DO mobile on NPA 829' => { iso: 'DO', prefix: '+1', number: '8292001234' },
    'a DO mobile on NPA 849' => { iso: 'DO', prefix: '+1', number: '8492001234' }
  }.freeze

  SYNTACTICALLY_INVALID = {
    'the legacy factory number +48111222331' => { iso: 'PL', prefix: '+48', number: '111222331' },
    'a non numeric string' => { iso: 'PL', prefix: '+48', number: 'notanumber' },
    'the short code 55555' => { iso: 'US', prefix: '+1', number: '55555' },
    'the short code 116' => { iso: 'US', prefix: '+1', number: '116' }
  }.freeze

  VALID_BUT_NOT_ELIGIBLE = {
    'a PL landline' => PL_LANDLINE,
    'a US premium-rate number' => US_PREMIUM,
    'a PL premium-rate number' => PL_PREMIUM,
    'a US toll-free number' => US_TOLL_FREE
  }.freeze

  ELIGIBLE_INTERNATIONAL = {
    'a GB mobile' => GB_MOBILE,
    'a FR mobile' => FR_MOBILE,
    'a DE mobile' => DE_MOBILE
  }.freeze
end
