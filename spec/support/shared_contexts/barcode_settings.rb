# frozen_string_literal: true

# Henry Ford's values (its label layout and the OID of the patient ID): CI's .env.template leaves them blank.
RSpec.shared_context 'with barcode settings configured' do
  include_context 'with environment variables', {
    'EHR_BARCODE_SCAN_FEATURE_ENABLED' => '1',
    'EHR_BARCODE_PATIENT_ID_PATTERN' => '<PtID> *(?<patient_id>[A-Za-z0-9]{1,10}) *</PtID>',
    'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => 'urn:oid:1.2.840.114350.1.13.338.3.7.2.698084'
  }
end
