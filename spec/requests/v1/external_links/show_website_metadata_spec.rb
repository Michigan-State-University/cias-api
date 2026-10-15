# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/show_website_metadata', type: :request do
  let!(:user) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:headers) { current_user.create_new_auth_token }
  let!(:params) do
    {
      url: url
    }
  end
  let(:request) { get v1_show_website_metadata_path, params: params, headers: headers }
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
    'Migrations are a feature of Active Record that allows you to evolve your ' \
      'database schema over time. Rather than write schema modifications in pure SQL, ' \
      'migrations allow you to use a Ruby Domain Specific Language (DSL) to describe changes ' \
      'to your tables.After reading this guide, you will know: ' \
      'Which generators you can use to create migrations. ' \
      'Which methods Active Record provides to manipulate your database. ' \
      'How to change existing migrations and update your schema. ' \
      'How migrations relate to schema.rb. How to maintain referential integrity.'
  end
  let(:title2) { 'Amazon.com' }

  # MetaInspector reaches out to the live web, which made this spec flaky (it depended
  # on external sites' markup/redirects being stable). We stub MetaInspector at the
  # gem boundary so the spec is deterministic and never touches the network — it
  # verifies the controller's own behaviour (building the metadata payload and
  # mapping MetaInspector failures to 422).
  let(:metainspector_error) { nil }
  let(:resolved_url) { url }
  let(:result_title) { title }
  let(:result_description) { description }
  let(:result_best_image) { 'https://guides.rubyonrails.org/images/og-image.png' }
  let(:result_images) { [result_best_image] }

  let(:metainspector_page) do
    images = double('MetaInspector::Images', best: result_best_image, as_json: result_images)
    double(
      'MetaInspector::Document',
      url: resolved_url,
      title: result_title,
      description: result_description,
      images: images,
      to_hash: {}
    )
  end

  before do
    if metainspector_error
      allow(MetaInspector).to receive(:new).and_raise(metainspector_error)
    else
      allow(MetaInspector).to receive(:new).and_return(metainspector_page)
    end
  end

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
          let(:resolved_url) { "https://www.#{url2}/" }
          let(:result_title) { 'Amazon.com. Spend less. Smile more.' }

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
          let(:metainspector_error) { MetaInspector::RequestError }

          it 'json response' do
            expect(response).to have_http_status(:unprocessable_entity)
          end

          context 'when page exist but doesn\'t exist subpage' do
            let(:url) { 'https://edgeguides.rubyonrails.org/wrong_path' }
            let(:metainspector_error) { nil }
            let(:result_title) { '404 Not Found' }
            let(:result_description) { nil }
            let(:result_best_image) { nil }

            it 'returns correct http status' do
              expect(response).to have_http_status(:ok)
            end

            it 'JSON contains proper attributes' do
              expect(json_response['url']).to eql(url)
              expect(json_response['title']).to eql('404 Not Found')
              expect(json_response['description']).to be_nil
              expect(json_response['image']).to be_nil
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
