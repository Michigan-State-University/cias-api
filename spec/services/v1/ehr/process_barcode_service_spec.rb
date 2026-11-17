# frozen_string_literal: true

RSpec.describe V1::Ehr::ProcessBarcodeService do
  # Henry Ford's values: the cases up to 'service initialization' are the contract that HF's codes
  # are read exactly as when its layout was hard-coded.
  include_context 'with barcode settings configured'

  describe '.call' do
    subject { described_class.call(verify_code_params) }

    let(:verify_code_params) { { barcode: barcode } }

    context 'when barcode contains valid patient ID' do
      let(:barcode) { '<PtID>Z394</PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'extracts patient ID correctly' do
        expect(subject).to eq('Z394')
      end
    end

    context 'when barcode contains patient ID with extra whitespace' do
      let(:barcode) { '<PtID>      Z394</PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'strips the label padding' do
        expect(subject).to eq('Z394')
      end
    end

    context 'when barcode contains numeric patient ID' do
      let(:barcode) { '<PtID>123456</PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'extracts numeric patient ID correctly' do
        expect(subject).to eq('123456')
      end
    end

    context 'when patient ID is 10 alphanumeric characters' do
      let(:barcode) { '<PtID>Z123456789</PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'accepts it' do
        expect(subject).to eq('Z123456789')
      end
    end

    # FHIR search syntax in the PtID would let the caller pick the identifier
    # system (`system|value`), OR several identifiers together (`,`) or escape (`\`).
    [
      'urn:oid:1.2.840.114350.1.13.338.3.7.5.737384.48|82000421',
      'Z394,Z13564,Z2550',
      'Z394\\,Z1',
      'ABC-123_DEF',
      'Z 394',
      'Z1234567890',
      # The fixed check allows "." and "-"; HF's format alone keeps rejecting them.
      'Z.394',
      'Z-394'
    ].each do |rejected_id|
      context "when patient ID is #{rejected_id.inspect}" do
        let(:barcode) { "<PtID>#{rejected_id}</PtID><PtDAT>54348</PtDAT><UID> " }

        it 'raises BarcodeParsingError with the parsing error message' do
          expect { subject }.to raise_error(
            Ehr::BarcodeParsingError,
            I18n.t('henry_ford.error.barcode.parsing_error')
          )
        end
      end
    end

    context 'when patient ID is empty' do
      let(:barcode) { '<PtID></PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when patient ID contains only whitespace' do
      let(:barcode) { '<PtID>   </PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when PtID tag is missing' do
      let(:barcode) { '<PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when barcode is malformed' do
      let(:barcode) { '<PtID>Z394<PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when barcode is completely invalid' do
      let(:barcode) { 'invalid barcode format' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when barcode is nil' do
      let(:barcode) { nil }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end
  end

  describe '#call' do
    subject { described_class.new(verify_code_params).call }

    let(:verify_code_params) { { barcode: barcode } }

    context 'when called as instance method' do
      let(:barcode) { '<PtID>Z394</PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'extracts patient ID correctly' do
        expect(subject).to eq('Z394')
      end
    end

    context 'when instance method raises error' do
      let(:barcode) { '<PtID></PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          Ehr::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end
  end

  describe 'service initialization' do
    let(:verify_code_params) { { barcode: '<PtID>Z394</PtID>' } }
    let(:service) { described_class.new(verify_code_params) }

    it 'stores verify_code_params' do
      expect(service.verify_code_params).to eq(verify_code_params)
    end

    it 'has accessible verify_code_params' do
      expect(service).to respond_to(:verify_code_params)
    end
  end

  describe 'with another site\'s settings' do
    context 'when the ID follows a prefix and only digits are valid' do
      include_context 'with environment variables', {
        'EHR_BARCODE_PATIENT_ID_PATTERN' => 'ID:(?<patient_id>[^;]*)',
        'EHR_BARCODE_PATIENT_ID_FORMAT' => '\A\d{4,8}\z'
      }

      it 'extracts the ID from that layout' do
        expect(described_class.call({ barcode: 'SITE;ID:12345;NAME:X' })).to eq('12345')
      end

      it 'applies that site\'s format' do
        expect { described_class.call({ barcode: 'ID:Z394;' }) }
          .to raise_error(Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.parsing_error'))
      end

      it 'does not read Henry Ford\'s layout' do
        expect { described_class.call({ barcode: '<PtID>12345</PtID>' }) }
          .to raise_error(Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.patient_id_empty'))
      end
    end

    # The code holds only the ID, and the site sets no format: only the fixed check applies.
    context 'when the code is the plain ID and no format is set' do
      include_context 'with environment variables', {
        'EHR_BARCODE_PATIENT_ID_PATTERN' => '\A(?<patient_id>.*)\z',
        'EHR_BARCODE_PATIENT_ID_FORMAT' => nil
      }

      it 'accepts letters, digits, dots and hyphens' do
        expect(described_class.call({ barcode: ' Z25.50-1 ' })).to eq('Z25.50-1')
      end

      it 'accepts up to 64 characters' do
        expect(described_class.call({ barcode: 'Z' * 64 })).to eq('Z' * 64)
      end

      # FHIR search syntax would let the code pick the identifier system (`system|value`),
      # OR several identifiers together (`,`) or escape (`\`), so no setting can allow it.
      ['Z25|50', 'Z25,50', 'Z25\\50', 'Z25 50', 'Z' * 65].each do |rejected_id|
        it "rejects #{rejected_id.inspect} with the parsing error" do
          expect { described_class.call({ barcode: rejected_id }) }
            .to raise_error(Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.parsing_error'))
        end
      end
    end
  end

  describe 'length cap' do
    let(:label) { '<PtID>Z394</PtID>' }

    it 'reads a code of the maximum length' do
      barcode = label.ljust(described_class::MAX_BARCODE_LENGTH, 'x')

      expect(described_class.call({ barcode: barcode })).to eq('Z394')
    end

    it 'rejects a longer code before running the site\'s pattern' do
      pattern = Ehr::Settings.barcode_patient_id_pattern
      allow(Ehr::Settings).to receive(:barcode_patient_id_pattern).and_return(pattern)
      allow(pattern).to receive(:match).and_call_original
      barcode = label.ljust(described_class::MAX_BARCODE_LENGTH + 1, 'x')

      expect { described_class.call({ barcode: barcode }) }
        .to raise_error(Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.parsing_error'))
      expect(pattern).not_to have_received(:match)
    end
  end

  describe 'regexp timeout' do
    let(:barcode) { '<PtID>Z394</PtID>' }

    it 'turns a timeout of the pattern into the parsing error' do
      pattern = Ehr::Settings.barcode_patient_id_pattern
      allow(pattern).to receive(:match).and_raise(Regexp::TimeoutError)
      allow(Ehr::Settings).to receive(:barcode_patient_id_pattern).and_return(pattern)

      expect { described_class.call({ barcode: barcode }) }
        .to raise_error(Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.parsing_error'))
    end

    it 'turns a timeout of the format into the parsing error' do
      format = Ehr::Settings.barcode_patient_id_format
      allow(format).to receive(:match?).and_raise(Regexp::TimeoutError)
      allow(Ehr::Settings).to receive(:barcode_patient_id_format).and_return(format)

      expect { described_class.call({ barcode: barcode }) }
        .to raise_error(Ehr::BarcodeParsingError, I18n.t('henry_ford.error.barcode.parsing_error'))
    end
  end

  # Not a parsing error: a broken setting must fail every scan loudly (an unrescued 500 reported to Sentry).
  describe 'invalid settings' do
    include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => '<PtID>(.*?)</PtID>' }

    it 'raises the setting error, even for a code that would otherwise be rejected' do
      expect { described_class.call({ barcode: '' }) }
        .to raise_error(Ehr::Settings::InvalidSettingError, /EHR_BARCODE_PATIENT_ID_PATTERN/)
    end

    context "when HF's pattern was pasted with a trailing line break" do
      include_context 'with environment variables', { 'EHR_BARCODE_PATIENT_ID_PATTERN' => "<PtID>(?<patient_id>.*?)</PtID>\n" }

      it 'raises the setting error instead of rejecting every code as empty' do
        expect { described_class.call({ barcode: '<PtID>      Z394</PtID>' }) }
          .to raise_error(Ehr::Settings::InvalidSettingError, 'EHR_BARCODE_PATIENT_ID_PATTERN starts or ends with whitespace')
      end
    end
  end
end
