# frozen_string_literal: true

RSpec.describe V1::HfhsPatientDetailAnonymizedSerializer do
  subject { described_class.new(patient_detail).serializable_hash[:data][:attributes] }

  let(:patient_detail) do
    create(:hfhs_patient_detail,
           first_name: 'Jonathan',
           last_name: 'Doe',
           dob: Date.parse('1980-04-17'),
           patient_id: '89010892',
           phone_number: '+1 (234) 567-7890',
           sex: 'male',
           zip_code: '12345')
  end

  it 'masks the name down to its first two characters' do
    expect(subject[:first_name]).to eq('Jo******')
    expect(subject[:last_name]).to eq('Do*')
  end

  it 'reduces the date of birth to its year' do
    expect(subject[:dob]).to eq('1980')
  end

  it 'masks everything but the last four digits of the phone number' do
    expect(subject[:phone_number]).to eq('*******7890')
  end

  it 'masks everything but the last four characters of the MRN' do
    expect(subject[:mrn]).to eq('****0892')
  end

  # This payload is returned before the patient has confirmed anything, so it
  # must never carry an attribute in the clear.
  it 'does not expose any unmasked patient data' do
    expect(subject.keys).to match_array(%i[id first_name last_name dob phone_number mrn])
    expect(subject.values.join).not_to include('89010892', 'Jonathan', '12345')
  end

  context 'when a value is short enough that masking would reveal it' do
    let(:patient_detail) do
      create(:hfhs_patient_detail, first_name: 'Al', patient_id: '1234', phone_number: '12')
    end

    it 'masks it entirely' do
      expect(subject[:first_name]).to eq('**')
      expect(subject[:mrn]).to eq('****')
      expect(subject[:phone_number]).to eq('****')
    end
  end

  context 'when values are missing' do
    let(:patient_detail) { create(:hfhs_patient_detail, phone_number: nil) }

    it 'returns nil rather than a mask' do
      expect(subject[:phone_number]).to be_nil
    end
  end
end
