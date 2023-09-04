# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::UpdateService do
  let(:subject) { described_class.call(intervention, predefined_participant, params) }
  let!(:intervention) { create(:intervention) }
  let!(:health_clinic_id) { create(:health_clinic).id }
  let(:predefined_participant) { create(:user, :predefined_participant, :with_phone, predefined_user_parameter: PredefinedUserParameter.new(intervention: intervention)) }
  let(:params) do
    {
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      health_clinic_id: health_clinic_id,
      phone_attributes: {
        number: '878987384'
      }
    }
  end

  it 'service return a created user' do
    expect(subject.instance_of?(User)).to be true
  end

  it 'change the user attributes' do
    expect(subject.slice(:first_name, :last_name)).to include(params.except(:health_clinic_id, :phone_attributes))
  end

  it 'change the phone number' do
    expect(subject.phone.number).to eql(params[:phone_attributes][:number])
  end

  it 'change clinic id' do
    expect(subject.predefined_user_parameter.health_clinic_id).to eql health_clinic_id
  end
end
