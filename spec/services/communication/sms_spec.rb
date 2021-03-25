# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Communication::Sms do
  let(:message) { create :message, :with_code }
  let(:subject) { described_class.new(message.id) }
  let(:client) { subject.client }
  let(:call) { subject.send_message }

  it 'raise an error for non exist message' do
    expect { described_class.new('zzz') }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'has correct message body' do
    expect(subject.sms.body).to eq message.body
  end

  it 'has correct phone number' do
    expect(subject.sms.phone).to eq message.phone
  end

  describe '#send_message' do
    it 'changes message status to "success" after correct sending' do
      allow(client.messages).to receive(:create)
      expect { call }.to change { message.reload.status }.from('new').to('success')
    end

    context 'after unexpected error' do
      before do
        allow(client.messages).to receive(:create).and_raise(StandardError, 'Just error')
      end

      it 'changes message status to "error"' do
        expect { call }.to change { message.reload.status }.from('new').to('error')
      end

      it 'returns specific error' do
        call
        expect(subject.errors).to eq ['SMS sending error: StandardError, Just error']
      end
    end
  end
end
