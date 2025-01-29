# frozen_string_literal: true

RSpec.describe V1::SmsPlans::CancelScheduledSmses do
  subject { described_class.call(intervention_id) }

  let(:user) { create(:user, :participant, :confirmed) }
  let(:intervention) { create(:intervention) }
  let(:intervention_id) { intervention.id }
  let!(:session) { create(:session, intervention: intervention) }

  before do
    ActiveJob::Base.queue_adapter = :test
    SmsPlans::SendSmsJob.set(wait_until: 2.days.from_now).perform_later(Faker::PhoneNumber.cell_phone, Faker::Lorem.sentence, nil, user.id, false, session.id)
    SmsPlans::SendSmsJob.set(wait_until: 2.days.from_now).perform_later(Faker::PhoneNumber.cell_phone, Faker::Lorem.sentence, nil, user.id, false, session.id)
  end

  it 'cancels a scheduled job' do
    expect(Sidekiq::ScheduledSet.new.count).to be 0
    subject
  end
end
