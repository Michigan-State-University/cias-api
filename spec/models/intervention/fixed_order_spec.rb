# frozen_string_literal: true

RSpec.describe Intervention::FixedOrder, type: :model do
  context 'is valid' do
    %w[invited registered].each do |target|
      subject { create(:fixed_order_intervention, shared_to: target) }

      it do
        expect(subject).to be_valid
      end
    end
  end

  context 'is invalid' do
    subject do
      described_class.new(name: 'Test')
    end

    it do
      subject.shared_to = 'anyone'
      subject.validate
      expect(subject.errors[:wrong_sharing_target]).
        to include("Fixed order interventions can only be shared to registered participants (Got #{subject.shared_to})")
    end
  end
end
