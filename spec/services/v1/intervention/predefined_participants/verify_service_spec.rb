# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::VerifyService do
  let(:subject) { described_class.call(slug) }
  let(:slug) { 'slug' }

  context 'slug is correct' do

  end

  context 'slug is incorrect' do
    let(:slug) {'wrong_slug'}

    it 'raise exception' do
      expect { subject.call }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
