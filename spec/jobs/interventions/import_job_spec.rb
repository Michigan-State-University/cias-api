# frozen_string_literal: true

RSpec.describe Interventions::ImportJob, type: :job do
  subject { described_class.perform_later(user_id, JSON.parse(invalid_json_file).deep_transform_keys(&:to_sym)) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:user_id) { user.id }
  let!(:invalid_json_file) do
    File.read('spec/factories/json/invalid_intervention.json')
  end

  context 'with invalid intervention_hash' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'do not create intervention' do
      expect { subject }.to change(Intervention, :count).by(0)
    end
  end
end
