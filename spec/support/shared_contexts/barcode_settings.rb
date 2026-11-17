# frozen_string_literal: true

# For every spec that scans a code: CI's .env.template leaves the scan flag and the barcode settings blank,
# which turns scanning off. These are Henry Ford's values (its label layout and patient ID format, formerly
# hard-coded, and the OID of that ID), so the scan specs prove HF's codes are read exactly as before once the
# site configures them.
RSpec.shared_context 'with barcode settings configured' do
  include_context 'with environment variables', {
    'EHR_BARCODE_SCAN_FEATURE_ENABLED' => '1',
    'EHR_BARCODE_PATIENT_ID_PATTERN' => '<PtID>(?<patient_id>.*?)</PtID>',
    'EHR_BARCODE_PATIENT_ID_FORMAT' => '\A[A-Za-z0-9]{1,10}\z',
    'EPIC_ON_FHIR_BARCODE_IDENTIFIER_SYSTEM' => 'urn:oid:1.2.840.114350.1.13.338.3.7.2.698084'
  }
end
