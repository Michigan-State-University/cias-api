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
end
