# frozen_string_literal: true

RSpec.describe V1::HenryFord::ProcessBarcodeService do
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
      'Z1234567890'
    ].each do |rejected_id|
      context "when patient ID is #{rejected_id.inspect}" do
        let(:barcode) { "<PtID>#{rejected_id}</PtID><PtDAT>54348</PtDAT><UID> " }

        it 'raises BarcodeParsingError with the parsing error message' do
          expect { subject }.to raise_error(
            HenryFord::BarcodeParsingError,
            I18n.t('henry_ford.error.barcode.parsing_error')
          )
        end
      end
    end

    context 'when patient ID is empty' do
      let(:barcode) { '<PtID></PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          HenryFord::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when patient ID contains only whitespace' do
      let(:barcode) { '<PtID>   </PtID><PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          HenryFord::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when PtID tag is missing' do
      let(:barcode) { '<PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          HenryFord::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when barcode is malformed' do
      let(:barcode) { '<PtID>Z394<PtDAT>54348</PtDAT><UID> ' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          HenryFord::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when barcode is completely invalid' do
      let(:barcode) { 'invalid barcode format' }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          HenryFord::BarcodeParsingError,
          I18n.t('henry_ford.error.barcode.patient_id_empty')
        )
      end
    end

    context 'when barcode is nil' do
      let(:barcode) { nil }

      it 'raises BarcodeParsingError' do
        expect { subject }.to raise_error(
          HenryFord::BarcodeParsingError,
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
          HenryFord::BarcodeParsingError,
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
end
