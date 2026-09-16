# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/sms_links', type: :request do
  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create(:sms_plan, no_formula_text: no_formula_text, session: session) }
  let(:sms_link) { create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, link_type: link_type, variable: 'variable_1') }
  let(:sms_links_user) { create(:sms_links_user, sms_link: sms_link, user: user) }
  let(:request) { post v1_verify_sms_link_path, params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  context 'when params are valid' do
    let(:no_formula_text) { 'Test link: ::variable_1::' }
    let(:params) do
      {
        sms_link: {
          slug: sms_links_user.slug
        }
      }
    end

    context 'when link_type is website' do
      let(:link_type) { 'website' }

      it 'returns status :ok' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'recieves proper attributes' do
        request
        expect(json_response).to eq({ 'link_type' => 'website', 'redirect_url' => sms_link.url })
      end
    end

    context 'when link_type is video' do
      let(:link_type) { 'video' }

      it 'returns status :ok' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'recieves proper attributes' do
        request
        expect(json_response).to eq({ 'link_type' => 'video', 'redirect_url' => sms_link.url })
      end
    end

    context 'when user is a predefined participant' do
      let(:user) { create(:user, :confirmed, :predefined_participant) }
      let(:link_type) { 'website' }
      let(:pid) { user.predefined_user_parameter.slug }

      context 'when sms_link url is an intervention session fill link' do
        let(:sms_link) do
          create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, link_type: link_type, variable: 'variable_1',
                            url: "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/sessions/#{session.id}/fill")
        end

        it 'appends pid to the redirect url' do
          request
          expect(json_response['redirect_url']).to include("pid=#{pid}")
        end
      end

      context 'when sms_link url is an intervention invite link' do
        let(:sms_link) do
          create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, link_type: link_type, variable: 'variable_1',
                            url: "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/invite")
        end

        it 'appends pid to the redirect url' do
          request
          expect(json_response['redirect_url']).to include("pid=#{pid}")
        end
      end

      context 'when sms_link url is an external link' do
        let(:sms_link) do
          create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, link_type: link_type, variable: 'variable_1',
                            url: 'https://example.com/some-resource')
        end

        it 'does not append pid to the redirect url' do
          request
          expect(json_response['redirect_url']).to eq('https://example.com/some-resource')
        end
      end

      context 'when sms_link url already has pid' do
        let(:sms_link) do
          create(:sms_link, sms_plan: sms_plan, session: sms_plan.session, link_type: link_type, variable: 'variable_1',
                            url: "#{ENV.fetch('WEB_URL')}/interventions/#{intervention.id}/sessions/#{session.id}/fill?pid=existing")
        end

        it 'does not duplicate the pid parameter' do
          request
          expect(json_response['redirect_url']).to include('pid=existing')
          expect(json_response['redirect_url']).not_to include(pid)
        end
      end
    end
  end
end
