# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/show_website_metadata', type: :request do
  WebMock.disable!
  WebMock.allow_net_connect!

  let!(:user) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:guest) { create(:user, :confirmed, :guest) }
  let!(:current_user) { user }
  let!(:users) do
    {
      admin: user,
      researcher: researcher,
      participant: participant,
      guest: guest
    }
  end

  let!(:url) { 'https://guides.rubyonrails.org/active_record_migrations.html' }
  let!(:url2) { 'amazon.com' }
  let(:title) { 'Active Record Migrations — Ruby on Rails Guides' }
  let(:description) do
    'Active Record MigrationsMigrations are a feature of Active Record that allows you to evolve your database schema over time. Rather than write schema modifications in pure SQL, migrations allow you to use a Ruby DSL to describe changes to your tables.After reading this guide, you will know: The generators you can use to create them. The methods Active Record provides to manipulate your database. The rails commands that manipulate migrations and your schema. How migrations relate to schema.rb.' # rubocop:disable Layout/LineLength
  end
  let(:title2) { 'Amazon.com' }
  let(:headers) { current_user.create_new_auth_token }
  let!(:params) do
    {
      url: url
    }
  end
  let(:request) { get v1_show_website_metadata_path, params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_show_website_metadata_path, params: params }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  %i[admin researcher participant guest].each do |role|
    context "when current user is #{role}" do
      let!(:current_user) { users[role] }

      before do
        request
      end

      context 'without params' do
        let!(:params) { {} }

        it 'returns correct http status' do
          expect(response).to have_http_status(:expectation_failed)
        end
      end

      context 'with params' do
        context 'when url is valid' do
          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'JSON contains proper attributes' do
            expect(json_response['url']).to eql(url)
            expect(json_response['title']).to eql(title)
            expect(json_response['description']).to eql(description)
            expect(json_response['images'].size).to be(1)
          end
        end

        context 'when url is valid but in short form' do
          let!(:params) do
            {
              url: url2
            }
          end

          it 'returns correct http status' do
            expect(response).to have_http_status(:ok)
          end

          it 'JSON contains proper attributes' do
            expect(json_response['url']).to eql("https://www.#{url2}/")
            expect(json_response['title']).to include(title2)
          end
        end

        context 'when url is invalid' do
          let(:url) { 'invalid path' }

          it 'json response ' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          context 'when page exist but doesn\'t exist subpage' do
            let(:url) { 'https://edgeguides.rubyonrails.org/wrong_path' }

            it 'returns correct http status' do
              expect(response).to have_http_status(:ok)
            end

            it 'JSON contains proper attributes' do
              expect(json_response['url']).to eql(url)
              expect(json_response['title']).to eql('404 Not Found')
              expect(json_response['description']).to be(nil)
              expect(json_response['image']).to be(nil)
            end
          end

          context 'when url has correct structure' do
            let(:url) { 'https://pl.test.org/test1234' }

            it 'returns correct http status' do
              expect(response).to have_http_status(:unprocessable_entity)
            end
          end
        end
      end
    end
  end
end
