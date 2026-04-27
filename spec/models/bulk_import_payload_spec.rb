# frozen_string_literal: true

RSpec.describe BulkImportPayload do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user_id: researcher.id) }
  let(:payload_value) do
    [
      { 'attributes' => { 'first_name' => 'Alice', 'last_name' => 'Smith', 'email' => 'alice@example.test' },
        'variable_answers' => { 's1.var1' => '1' } },
      { 'attributes' => { 'first_name' => 'Bob', 'last_name' => 'Jones' }, 'variable_answers' => {} }
    ]
  end

  describe 'associations' do
    it 'requires a researcher' do
      record = described_class.new(intervention: intervention, payload: payload_value)
      expect(record).not_to be_valid
      expect(record.errors[:researcher]).to be_present
    end

    it 'requires an intervention' do
      record = described_class.new(researcher: researcher, payload: payload_value)
      expect(record).not_to be_valid
      expect(record.errors[:intervention]).to be_present
    end

    it 'is valid with researcher + intervention + payload' do
      record = described_class.new(researcher: researcher, intervention: intervention, payload: payload_value)
      expect(record).to be_valid
    end
  end

  describe 'payload encryption (Lockbox)' do
    subject(:record) do
      described_class.create!(researcher: researcher, intervention: intervention, payload: payload_value)
    end

    it 'round-trips the payload through Lockbox' do
      reloaded = described_class.find(record.id)
      expect(reloaded.payload).to eq(payload_value)
    end

    it 'populates the payload_ciphertext column on save' do
      expect(record.read_attribute(:payload_ciphertext)).to be_present
    end

    it 'stores ciphertext, not plaintext JSON, in the column' do
      raw = record.read_attribute(:payload_ciphertext)
      expect(raw).not_to include('alice@example.test')
      expect(raw).not_to include('Alice')
      expect(raw).not_to include('Bob')
    end
  end

  describe 'audit trail' do
    it 'creates audit rows on create + destroy' do
      record = nil
      expect do
        record = described_class.create!(researcher: researcher, intervention: intervention, payload: payload_value)
      end.to change { record&.audits&.count || 0 }.by_at_least(0) # create-side audit counted below

      expect(record.audits.where(action: 'create').count).to eq(1)

      expect { record.destroy }.to change {
        Audited::Audit.where(auditable_type: described_class.name, action: 'destroy').count
      }.by(1)
    end

    it 'excludes payload_ciphertext from audited_changes' do
      record = described_class.create!(researcher: researcher, intervention: intervention, payload: payload_value)
      create_audit = record.audits.find_by(action: 'create')

      expect(create_audit.audited_changes.keys).not_to include('payload_ciphertext')
      expect(create_audit.audited_changes.keys).not_to include('payload')
    end
  end

  describe 'paper_trail' do
    it 'does not create Version rows (model does not declare has_paper_trail)' do
      expect do
        record = described_class.create!(researcher: researcher, intervention: intervention, payload: payload_value)
        record.destroy
      end.not_to change { PaperTrail::Version.where(item_type: described_class.name).count }
    end
  end
end
