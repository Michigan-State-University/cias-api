# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::CreateService do
  let(:subject) { described_class.call(intervention, params) }
  let!(:intervention) { create(:intervention) }
  let!(:health_clinic_id) { create(:health_clinic).id }
  let(:params) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      health_clinic_id: health_clinic_id,
      auto_invitation: true,
      phone_attributes: {
        iso: 'PL',
        prefix: '+48',
        number: '777888999'
      }
    }
  end

  it 'service return a created user' do
    expect(subject.instance_of?(User)).to be true
  end

  it 'create a predefined user' do
    expect { subject }.to change(User, :count).by(1)
  end

  it 'create a phone' do
    expect { subject }.to change(Phone, :count).by(1)
  end

  it 'create a predefined participant params' do
    expect { subject }.to change(PredefinedUserParameter, :count).by(1)
  end

  it 'returned user has correct parameters' do
    expect(subject.slice(:first_name, :last_name,
                         :roles).deep_transform_keys!(&:to_s)).to include({ first_name: params[:first_name], last_name: params[:last_name],
                                                                            roles: ['predefined_participant'] })
  end

  it 'user has assigned phone' do
    expect(subject.phone).to be_present
  end

  it 'user has predefined user parameter' do
    expect(subject.predefined_user_parameter).to be_present
  end

  it 'predefined user parameters has correct values' do
    expect(subject.predefined_user_parameter.auto_invitation).to be true
  end

  context 'when phone_attributes are skipped' do
    let(:params) do
      {
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        health_clinic_id: health_clinic_id
      }
    end

    it 'doesn\'t create a phone' do
      expect { subject }.not_to change(Phone, :count)
    end
  end
end