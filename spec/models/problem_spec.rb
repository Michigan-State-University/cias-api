# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Problem, type: :model do
  context 'Problem' do
    subject { create(:problem) }

    let(:initial_status) { subject }

    it { should belong_to(:user) }
    it { should have_many(:interventions) }
    it { should be_valid }
    it { expect(initial_status.draft?).to be true }
  end

  context 'change states' do
    context 'draft to published' do
      let(:problem) { create(:problem) }

      it 'sucess event' do
        problem.broadcast
        problem.save
        expect(problem.published?).to be true
      end
    end

    context 'published to closed' do
      let(:problem) { create(:problem, :published) }

      it 'sucess event' do
        problem.close
        problem.save
        expect(problem.closed?).to be true
      end
    end

    context 'closed to archived' do
      let(:problem) { create(:problem, :closed) }

      it 'sucess event' do
        problem.to_archive
        problem.save
        expect(problem.archived?).to be true
      end
    end

    context 'draft to draft' do
      let(:problem) { create(:problem) }

      it 'sucess event' do
        problem.to_initial
        problem.save
        expect(problem.draft?).to be true
      end
    end

    context 'published to draft' do
      let(:problem) { create(:problem, :published) }

      it 'sucess event' do
        problem.to_initial
        problem.save
        expect(problem.draft?).to be true
      end
    end

    context 'closed to draft' do
      let(:problem) { create(:problem, :closed) }

      it 'sucess event' do
        problem.to_initial
        problem.save
        expect(problem.draft?).to be true
      end
    end

    context 'archived to draft' do
      let(:problem) { create(:problem, :archived) }

      it 'sucess event' do
        problem.to_initial
        problem.save
        expect(problem.draft?).to be true
      end
    end
  end
end
