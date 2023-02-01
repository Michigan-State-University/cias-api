# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::V1::InterventionAccessService do
  subject { described_class.call(intervention.id, access_hash) }

  let(:access_hash) do
    {
      email: 'avatar.aang@gmail.com',
      version: '1'
    }
  end

  let(:intervention) { create(:intervention) }

  it 'create access to intervention' do
    expect { subject }.to change(InterventionAccess, :count).by(1)
  end

  it 'is contained in the intervention' do
    subject
    expect(intervention.intervention_accesses.map(&:email)).to include(access_hash[:email])
  end
end
