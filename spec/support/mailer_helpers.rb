# frozen_string_literal: true

module MailerHelpers
  def expect_to_call_mailer(mailer, method, args: nil, params: nil, return_value: nil)
    # rubocop: disable RSpec/StubbedMock
    expect(ActionMailer::Parameterized::MessageDelivery).to receive(:new)
            .with(mailer, method, params.presence || anything, *args.presence || any_args)
            .and_return(return_value || anything)
    # rubocop: enable RSpec/StubbedMock
  end
end
