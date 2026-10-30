# frozen_string_literal: true

require 'rails_helper'

RSpec.describe(HfhsPatientDetail) do
  it { should validate_presence_of(:patient_id) }

  describe 'phone_type enum scopes' do
    let!(:home_detail) { create(:hfhs_patient_detail, phone_type: 'home') }
    let!(:mobile_detail) { create(:hfhs_patient_detail, phone_type: 'mobile') }

    it 'query the encrypted phone_type through its blind index' do
      expect(described_class.home.to_sql).to include('"phone_type_bidx" =')
    end

    it 'return records with the matching phone_type' do
      expect(described_class.home).to contain_exactly(home_detail)
      expect(described_class.mobile).to contain_exactly(mobile_detail)
      expect(described_class.not_mobile).to contain_exactly(home_detail)
    end
  end
end
