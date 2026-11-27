# frozen_string_literal: true

require 'rails_helper'

# Hfhs::SendAnswersJob's spec stubs Api::Hl7Receiver.new, so these are the only
# examples that run the facade's two delegations.
RSpec.describe Api::Hl7Receiver do
  subject(:api) { described_class.new }

  let(:user_session_id) { SecureRandom.uuid }

  describe '#send_answers' do
    it 'delivers the answers through Api::Hl7Receiver::UserSession' do
      allow(Api::Hl7Receiver::UserSession).to receive(:call)

      api.send_answers(user_session_id)

      expect(Api::Hl7Receiver::UserSession).to have_received(:call).with(user_session_id).once
    end
  end

  describe '#send_reports' do
    it 'delivers the reports through Api::Hl7Receiver::Reports' do
      allow(Api::Hl7Receiver::Reports).to receive(:call)

      api.send_reports(user_session_id)

      expect(Api::Hl7Receiver::Reports).to have_received(:call).with(user_session_id).once
    end
  end
end
