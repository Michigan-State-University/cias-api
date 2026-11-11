# frozen_string_literal: true

RSpec.describe V1::PredefinedParticipants::ReportSmsError do
  let(:error_class) { Class.new(StandardError) }

  it 'sends only the given label under the given class, with the extra context' do
    allow(Sentry).to receive(:capture_exception)
    described_class.call(error_class, 'Twilio::REST::RestError', extra: { campaign_id: 'c1' })
    expect(Sentry).to have_received(:capture_exception) do |error, extra:|
      expect([error.class, error.message, error.backtrace, extra]).to eq([error_class, 'Twilio::REST::RestError', nil, { campaign_id: 'c1' }])
    end
  end

  it 'keeps the backtrace of the original error when given' do
    allow(Sentry).to receive(:capture_exception)
    described_class.call(error_class, 'x', extra: {}, backtrace: %w[a.rb:1])
    expect(Sentry).to have_received(:capture_exception) { |error, **| expect(error.backtrace).to eq(%w[a.rb:1]) }
  end
end
