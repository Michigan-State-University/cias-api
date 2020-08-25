# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/users/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:alter_user) { create(:user, :confirmed) }
  let(:headers) do
    user.create_new_auth_token
  end
  let(:params_address_attributes_blank) do
    { user: {
      last_name: 'test',
      address_attributes: {}
    } }
  end
  let(:params_without_address) do
    { user: {
      last_name: 'test'
    } }
  end
  let(:params_one_attribute) do
    {
      user: {
        address_attributes: {
          name: 'name'
        }
      }
    }
  end
  let(:params) do
    {
      user: {
        address_attributes: {
          name: 'name',
          country: 'United States of America',
          state: 'state',
          state_abbreviation: 'state_abbr',
          city: 'city',
          zip_code: 'zip_code',
          street: 'street_name',
          building_address: 'building_number',
          apartment_number: 'apartment_number'
        }
      }
    }
  end

  context 'response' do
    context 'blank address params' do
      before do
        patch v1_user_path(id: alter_user.id), params: params_address_attributes_blank, headers: headers
      end

      it 'address is empty' do
        expect(json_response['data']['attributes']['address_attributes'].compact.empty?).to be true
      end
    end

    context 'params wihtout address' do
      before do
        patch v1_user_path(id: alter_user.id), params: params_without_address, headers: headers
      end

      it 'returns nil in every address attribute' do
        expect(json_response['data']['attributes']['address_attributes'].compact.empty?).to be true
      end
    end

    context 'one value, rest nil' do
      before do
        patch v1_user_path(id: alter_user.id), params: params_one_attribute, headers: headers
      end

      it 'address containst one key' do
        expect(json_response['data']['attributes']['address_attributes']).to have_key('name')
      end
    end

    context 'all values' do
      before do
        patch v1_user_path(id: alter_user.id), params: params, headers: headers
      end

      it 'address keys assigned' do
        expect(json_response['data']['attributes']['address_attributes']).to include('name' => 'name',
                                                                                     'country' => 'United States of America', 'state' => 'state', 'state_abbreviation' => 'state_abbr',
                                                                                     'city' => 'city', 'zip_code' => 'zip_code', 'street' => 'street_name', 'building_address' => 'building_number',
                                                                                     'apartment_number' => 'apartment_number')
      end
    end
  end
end
