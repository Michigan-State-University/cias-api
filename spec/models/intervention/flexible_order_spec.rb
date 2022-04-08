# frozen_string_literal: true

RSpec.describe Intervention::FlexibleOrder, type: :model do
  context 'is valid' do
    subject { create(:flexible_order_intervention, shared_to: 'registered', sessions: sessions) }

    let(:sessions) do
      create_list(:session, 3)
    end

    it do
      expect(subject).to be_valid
    end
  end

  context 'is invalid' do
    subject { create(:flexible_order_intervention, shared_to: 'registered') }

    context 'invalid sharing target' do
      it do
        subject.shared_to = 'anyone'
        subject.validate
        expect(subject.errors[:wrong_sharing_target]).
          to include("Flexible order interventions can only be shared to registered participants (Got #{subject.shared_to})")
      end
    end
  end
end
