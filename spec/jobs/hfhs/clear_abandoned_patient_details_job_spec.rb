# frozen_string_literal: true

RSpec.describe Hfhs::ClearAbandonedPatientDetailsJob, type: :job do
  subject { described_class.perform_now }

  let(:retention) { described_class::RETENTION_PERIOD }

  let!(:abandoned_draft) do
    create(:hfhs_patient_detail, pending: true).tap { |record| record.update_column(:updated_at, retention.ago - 1.hour) }
  end

  it 'removes drafts nobody confirmed' do
    expect { subject }.to change(HfhsPatientDetail, :count).by(-1)
    expect(HfhsPatientDetail.exists?(abandoned_draft.id)).to be false
  end

  context 'when a draft is still within the retention period' do
    let!(:fresh_draft) { create(:hfhs_patient_detail, pending: true) }

    it 'keeps it' do
      subject
      expect(HfhsPatientDetail.exists?(fresh_draft.id)).to be true
    end
  end

  context 'when a record has been confirmed' do
    let!(:confirmed) do
      create(:hfhs_patient_detail, pending: false).tap { |record| record.update_column(:updated_at, retention.ago - 1.hour) }
    end

    it 'keeps it' do
      subject
      expect(HfhsPatientDetail.exists?(confirmed.id)).to be true
    end
  end

  context 'when a stale draft is still matched to a user' do
    let!(:matched_draft) do
      create(:hfhs_patient_detail, pending: true).tap do |record|
        create(:user, :participant, :confirmed, hfhs_patient_detail: record)
        record.update_column(:updated_at, retention.ago - 1.hour)
      end
    end

    it 'keeps it' do
      subject
      expect(HfhsPatientDetail.exists?(matched_draft.id)).to be true
    end
  end
end
