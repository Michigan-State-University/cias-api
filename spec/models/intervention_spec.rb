# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention, type: :model do
  context 'Intervention' do
    subject { create(:intervention) }

    let(:initial_status) { subject }

    it { should belong_to(:user) }
    it { should have_many(:sessions) }
    it { should be_valid }
    it { expect(initial_status.draft?).to be true }
  end

  context 'change states' do
    context 'draft to published' do
      let(:intervention) { create(:intervention) }
      let(:sessions) { create_list(:session, 4, intervention_id: intervention.id) }

      it 'success event' do
        sessions
        intervention.broadcast
        intervention.save
        expect(intervention.published?).to be true
      end
    end

    context 'published to closed' do
      let(:intervention) { create(:intervention, :published) }

      it 'success event' do
        intervention.close
        intervention.save
        expect(intervention.closed?).to be true
      end
    end

    context 'closed to archived' do
      let(:intervention) { create(:intervention, :closed) }

      it 'success event' do
        intervention.to_archive
        intervention.save
        expect(intervention.archived?).to be true
      end
    end

    context 'draft to draft' do
      let(:intervention) { create(:intervention) }

      it 'success event' do
        intervention.to_initial
        intervention.save
        expect(intervention.draft?).to be true
      end
    end

    context 'published to draft' do
      let(:intervention) { create(:intervention, :published) }

      it 'success event' do
        intervention.to_initial
        intervention.save
        expect(intervention.draft?).to be true
      end
    end

    context 'closed to draft' do
      let(:intervention) { create(:intervention, :closed) }

      it 'success event' do
        intervention.to_initial
        intervention.save
        expect(intervention.draft?).to be true
      end
    end

    context 'archived to draft' do
      let(:intervention) { create(:intervention, :archived) }

      it 'success event' do
        intervention.to_initial
        intervention.save
        expect(intervention.draft?).to be true
      end
    end
  end
end
