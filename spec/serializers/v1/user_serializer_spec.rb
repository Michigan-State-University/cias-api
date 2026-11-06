# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::UserSerializer do
  subject(:attributes) { described_class.new(user).serializable_hash[:data][:attributes] }

  describe '#health_clinics_ids' do
    context 'when user is a health clinic admin' do
      let(:user) { create(:user, :confirmed, :health_clinic_admin) }

      before do
        create_list(:health_clinic, 2).each { |health_clinic| UserHealthClinic.create!(user: user, health_clinic: health_clinic) }
      end

      it 'returns plain hashes that can be stored in the serializer cache' do
        expect(attributes[:health_clinics_ids]).to eq(user.user_health_clinics.map { |user_health_clinic| { 'id' => user_health_clinic.id } })
      end
    end

    context 'when user is not a health clinic admin' do
      let(:user) { create(:user, :confirmed, :researcher) }

      it 'returns nil' do
        expect(attributes[:health_clinics_ids]).to be_nil
      end
    end
  end
end
