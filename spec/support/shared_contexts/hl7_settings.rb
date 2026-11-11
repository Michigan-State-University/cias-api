# frozen_string_literal: true

# For every spec that builds an HL7 message: CI's .env.template leaves the HL7 values blank, which makes
# the mappers raise. These are the values Henry Ford's receiving system assigned (formerly hard-coded),
# so the pinned MSH/TXA/OBX strings prove the output is byte-identical once a site configures them.
RSpec.shared_context 'with HL7 settings configured' do
  include_context 'with environment variables', {
    'HL7_SENDING_FACILITY' => 'HFHS',
    'HL7_RECEIVING_FACILITY' => 'HFH',
    'HL7_DOCUMENT_TYPE' => 'DASST-D',
    'HL7_OBSERVATION_VALUE_PREFIX' => 'EpicWBS^PDF^Base64'
  }
end
