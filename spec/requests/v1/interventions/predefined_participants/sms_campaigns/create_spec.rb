# frozen_string_literal: true

require 'rails_helper'
require 'support/predefined_participant_sms_helpers'

RSpec.describe 'POST /v1/interventions/:intervention_id/predefined_participants/sms_campaigns', type: :request do
  include PredefinedParticipantSmsHelpers

  let(:sql_leak) { /PG::|duplicate key|index_pp|INSERT INTO|violates|unique constraint|constraint|ActiveRecord/i }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let!(:intervention) { create(:intervention, :published, user: researcher) }
  let(:path) { "/v1/interventions/#{intervention.id}/predefined_participants/sms_campaigns" }
  let(:campaign_params) { { kind: 'invitation', body: canary_body, links: [] } }
  let(:params) { { sms_campaign: campaign_params } }
  let(:request) { post path, params: params, headers: current_user.create_new_auth_token, as: :json }
  let(:campaigns) { PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id) }

  before do
    make_participant(intervention, index: 0)
    make_participant(intervention, index: 1)
  end

  describe 'invitation with a scheduled reminder' do
    let(:campaign_params) do
      { kind: 'invitation', body: canary_body, links: [], scheduled_reminder: { body: 'CIAS_TDD_REMINDER_BODY', days_after: 3, links: [] } }
    end

    it 'answers 202 with the invitation and creates the reminder as its scheduled child' do
      request
      expect(response).to have_http_status(:accepted)
      invitation = campaigns.find_by!(kind: 'invitation')
      expect(json_response['data']['id']).to eq(invitation.id)
      expect(campaigns.find_by(kind: 'scheduled_reminder'))
        .to have_attributes(parent_campaign_id: invitation.id, days_after: 3, body: 'CIAS_TDD_REMINDER_BODY', status: 'scheduled')
    end

    context 'when the reminder carries a tracked link' do
      let(:campaign_params) do
        { kind: 'invitation', body: canary_body, links: [],
          scheduled_reminder: { body: 'Remind ::canary_link::', days_after: 3, links: [link_params] } }
      end

      it 'stores the link on the reminder' do
        request
        expect(response).to have_http_status(:accepted)
        expect(campaigns.find_by!(kind: 'scheduled_reminder').sms_links.pluck(:variable, :url)).to eq([['canary_link', PredefinedParticipantSmsHelpers::TRACKED_URL]])
      end
    end
  end

  describe 'happy path' do
    it 'answers 202 with the serialized campaign' do
      request
      expect(response).to have_http_status(:accepted)
      expect(json_response['data']['id']).to eq(campaigns.sole.id)
      expect(json_response['data']['attributes']).to include('kind' => 'invitation', 'status' => 'scheduled')
    end

    it 'persists a scheduled campaign authored by the current user' do
      request
      expect(response).to have_http_status(:accepted)
      expect(campaigns.sole).to have_attributes(kind: 'invitation', status: 'scheduled', body: canary_body, author_id: researcher.id)
    end

    it 'enqueues the campaign job for the created campaign' do
      expect { request }.to have_enqueued_job(PredefinedParticipants::SendSmsCampaignJob)
      expect(response).to have_http_status(:accepted)
      expect(PredefinedParticipants::SendSmsCampaignJob).to have_been_enqueued.with(campaigns.sole.id)
    end

    it 'does not send anything synchronously' do
      expect { request }.not_to change(Message, :count)
      expect(response).to have_http_status(:accepted)
    end

    it 'stores and returns the recipient count counted at creation time' do
      make_participant(intervention, index: 2, phone: nil)
      make_participant(intervention, index: 3, active: false)
      request
      expect(response).to have_http_status(:accepted)
      expect(json_response['data']['attributes']['recipients_count']).to eq(2)
      expect(campaigns.sole.recipients_count).to eq(2)
    end

    it 'creates the tracked links sent inline with the campaign' do
      payload = { kind: 'invitation', body: "#{canary_body} ::#{canary_variable}::", links: [link_param] }
      post path, params: { sms_campaign: payload }, headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:accepted)
      expect(campaigns.sole.sms_links.pluck(:url, :variable)).to eq([[canary_url, canary_variable]])
    end

    it 'accepts a manual_reminder once the participants have been invited' do
      PredefinedUserParameter.where(intervention_id: intervention.id).update_all(sms_invitation_sent_at: 3.days.ago)
      post path, params: { sms_campaign: { kind: 'manual_reminder', body: canary_body } }, headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:accepted)
      expect(campaigns.sole.kind).to eq('manual_reminder')
    end

    it 'returns the stored body so the created campaign reads back like the one on the list' do
      request
      expect(response).to have_http_status(:accepted)
      expect(json_response['data']['attributes']['body']).to eq(canary_body)
    end

    def link_param
      { url: canary_url, variable: canary_variable, link_type: 'website' }
    end
  end

  describe 'authentication' do
    it 'answers 401 without a token' do
      post path, params: params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates nothing and enqueues nothing without a token' do
      expect { post path, params: params, as: :json }.not_to change(PredefinedParticipants::SmsCampaign, :count)
      expect(response).to have_http_status(:unauthorized)
      expect { post path, params: params, as: :json }.not_to have_enqueued_job(PredefinedParticipants::SendSmsCampaignJob)
    end
  end

  describe 'role checks' do
    it_behaves_like 'users without access'

    it 'other researcher creates nothing' do
      other = create(:user, :researcher, :confirmed)
      expect { post path, params: params, headers: other.create_new_auth_token, as: :json }.not_to change(PredefinedParticipants::SmsCampaign, :count)
      expect(response).to have_http_status(:not_found)
    end

    it 'other role creates nothing' do
      other = create(:user, :participant, :confirmed)
      expect { post path, params: params, headers: other.create_new_auth_token, as: :json }.not_to change(PredefinedParticipants::SmsCampaign, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'other role never reaches the job' do
      other = create(:user, :participant, :confirmed)
      expect { post path, params: params, headers: other.create_new_auth_token, as: :json }
        .not_to have_enqueued_job(PredefinedParticipants::SendSmsCampaignJob)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'current editor gate' do
    let(:collaborator) { create(:user, :researcher, :confirmed) }

    before do
      create(:collaborator, intervention: intervention, user: collaborator, edit: true, view: true)
    end

    it 'answers 403 to a collaborator with edit: true who is not the current editor' do
      intervention.update!(current_editor: researcher)
      post path, params: params, headers: collaborator.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'creates nothing and enqueues nothing for the non-editor' do
      intervention.update!(current_editor: researcher)
      expect { post path, params: params, headers: collaborator.create_new_auth_token, as: :json }
        .not_to change(PredefinedParticipants::SmsCampaign, :count)
      expect(response).to have_http_status(:forbidden)
      expect { post path, params: params, headers: collaborator.create_new_auth_token, as: :json }
        .not_to have_enqueued_job(PredefinedParticipants::SendSmsCampaignJob)
    end

    it 'answers 403 when nobody is the current editor' do
      post path, params: params, headers: collaborator.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'the same collaborator succeeds once they are the current editor' do
      intervention.update!(current_editor: collaborator)
      post path, params: params, headers: collaborator.create_new_auth_token, as: :json
      expect(response).to have_http_status(:accepted)
    end
  end

  describe 'intervention state refusals' do
    {
      'draft' => ['INTERVENTION_DRAFT', {}],
      'paused' => ['INTERVENTION_PAUSED', { status: 'paused' }],
      'closed' => ['INTERVENTION_CLOSED', { status: 'closed' }]
    }.each do |label, (reason, attributes)|
      it "answers 400 with details.reason #{reason} for a #{label} intervention" do
        target = create(:intervention, user: researcher, **attributes)
        make_participant(target, index: 5)
        post "/v1/interventions/#{target.id}/predefined_participants/sms_campaigns",
             params: params, headers: researcher.create_new_auth_token, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(json_response['message']).to be_a(String).and be_present
        expect(json_response['details']).to eq('reason' => reason)
        expect(PredefinedParticipants::SmsCampaign.where(intervention_id: target.id)).to be_empty
      end
    end
  end

  describe 'validation failures' do
    def error_codes_from_response
      json_response.dig('details', 'errors').pluck('code')
    end

    {
      'a blank body' => [{ kind: 'invitation', body: '' }, 'BODY_BLANK'],
      'an unknown kind' => [{ kind: 'bogus', body: 'CIAS_TDD_CANARY_BODY' }, 'INVALID_KIND'],
      'a body variable without a link' => [{ kind: 'invitation', body: 'CIAS_TDD_CANARY_BODY ::canary_link::' }, 'UNKNOWN_LINK_VARIABLE']
    }.each do |label, (campaign, code)|
      it "answers 422 with the error code #{code} for #{label}" do
        post path, params: { sms_campaign: campaign }, headers: researcher.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['message']).to be_a(String).and be_present
        expect(error_codes_from_response).to include(code)
        expect(PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id)).to be_empty
      end
    end

    it 'answers 422 NO_RECIPIENTS when nobody is eligible' do
      empty = create(:intervention, :published, :with_predefined_participants, user: researcher)
      post "/v1/interventions/#{empty.id}/predefined_participants/sms_campaigns",
           params: params, headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.dig('details', 'errors').pluck('code')).to include('NO_RECIPIENTS')
    end

    it 'returns error entries made of codes only' do
      post path, params: { sms_campaign: { kind: 'bogus', body: '' } }, headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      entries = json_response.dig('details', 'errors')
      expect(entries).to all(satisfy { |entry| entry.keys == ['code'] && entry['code'] =~ /\A[A-Za-z0-9_.:-]+\z/ })
    end

    it 'never echoes the submitted body in a validation response' do
      post path, params: { sms_campaign: { kind: 'bogus', body: canary_body } }, headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include(canary_body)
    end

    it 'answers 409 CAMPAIGN_IN_PROGRESS for a second overlapping campaign of the same kind' do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'scheduled')
      request
      expect(response).to have_http_status(:conflict)
      expect(json_response.dig('details', 'errors').pluck('code')).to include('CAMPAIGN_IN_PROGRESS')
    end

    it 'leaks neither SQL text nor an index name in the 409 body' do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'scheduled')
      request
      expect(response).to have_http_status(:conflict)
      expect(response.body).not_to match(sql_leak)
      expect(response.body).not_to include('index_pp_sms_campaigns_one_in_flight_per_kind')
    end

    it 'leaves a single campaign behind after the 409' do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'scheduled')
      expect { request }.not_to change(PredefinedParticipants::SmsCampaign, :count)
      expect(response).to have_http_status(:conflict)
    end
  end

  describe 'mass assignment' do
    let(:other_user) { create(:user, :researcher, :confirmed) }
    let(:campaign_params) do
      { kind: 'invitation', body: canary_body, status: 'sent', token: 'canary-token', organization_id: SecureRandom.uuid,
        sent_at: 1.day.ago.iso8601, author_id: other_user.id, recipients_count: 99, accepted_count: 98, failed_count: 97 }
    end

    it 'ignores client-supplied status, sent_at, author_id and counters' do
      request
      expect(response).to have_http_status(:accepted)
      expect(campaigns.sole).to have_attributes(status: 'scheduled', sent_at: nil, author_id: researcher.id, recipients_count: 2,
                                                accepted_count: 0, failed_count: 0)
    end

    it 'ignores the same attributes sent next to the sms_campaign key' do
      post path, params: params.merge(status: 'sent', author_id: other_user.id, sent_at: 1.day.ago.iso8601),
                 headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:accepted)
      expect(campaigns.sole).to have_attributes(status: 'scheduled', sent_at: nil, author_id: researcher.id)
    end

    it 'ignores a client-supplied intervention_id inside the campaign payload' do
      foreign = create(:intervention, :published, user: researcher)
      post path, params: { sms_campaign: campaign_params.merge(intervention_id: foreign.id) },
                 headers: researcher.create_new_auth_token, as: :json
      expect(response).to have_http_status(:accepted)
      expect(campaigns.count).to eq(1)
      expect(PredefinedParticipants::SmsCampaign.where(intervention_id: foreign.id)).to be_empty
    end
  end

  describe 'creation rules and access' do
    def created_campaign
      expect(response).to have_http_status(:accepted)
      campaigns.sole
    end

    def expect_coded422
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response.keys).to match_array(%w[message details])
      expect(json_response['details']['errors']).to all(include('code' => be_present))
      expect(campaigns).to be_empty
    end

    it 'the owning researcher is accepted (so the refusals come from the gate, not a missing route)' do
      request
      expect(response).to have_http_status(:accepted)
    end

    it 'answers 401 for a forged token' do
      post path, params: params, headers: { 'access-token' => 'forged', 'client' => 'forged', 'uid' => researcher.email }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    context 'when the kind is not creatable standalone' do
      let(:campaign_params) { { kind: 'scheduled_reminder', body: canary_body, links: [] } }

      it 'answers 422 with a code' do
        request
        expect_coded422
      end
    end

    context 'when a link has a forbidden scheme' do
      let(:campaign_params) do
        { kind: 'invitation', body: "#{canary_body} ::#{canary_variable}::",
          links: [{ url: 'javascript://canary', variable: canary_variable, link_type: 'website' }] }
      end

      it 'answers 422 with a code and no raw exception text' do
        request
        expect_coded422
        expect(response.body).not_to match(/Validation failed|ActiveRecord|PG::|RecordInvalid|Url/i)
      end
    end

    context 'when a campaign of the same kind is already in flight' do
      before { create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'scheduled') }

      it 'does not leak SQL text, the index name or the campaign body in the 409 body' do
        request
        expect(response).to have_http_status(:conflict)
        expect(response.body).not_to match(PredefinedParticipantSmsHelpers::LEAKY_SQL)
        expect(response.body).not_to match(/index_pp_|uuid_generate|predefined_participants_sms_campaigns/)
        expect(response.body).not_to include(canary_body)
      end
    end

    context 'when the client forges identifiers' do
      let(:forged_id) { SecureRandom.uuid }
      let(:other_author) { create(:user, :researcher, :confirmed) }
      let(:other_intervention) { create(:intervention, :published) }
      let(:campaign_params) do
        { kind: 'invitation', body: canary_body, links: [], status: 'sent', token: 'forged-token',
          organization_id: SecureRandom.uuid, sent_at: 1.day.ago.iso8601, author_id: other_author.id,
          intervention_id: other_intervention.id, id: forged_id, recipients_count: 999, accepted_count: 999,
          failed_count: 999 }
      end

      it 'ignores status, sent_at, author_id, intervention_id and id' do
        request
        expect(created_campaign).to have_attributes(status: 'scheduled', sent_at: nil, author_id: researcher.id,
                                                    intervention_id: intervention.id)
        expect(created_campaign.id).not_to eq(forged_id)
        expect(PredefinedParticipants::SmsCampaign.where(intervention_id: other_intervention.id)).to be_empty
      end

      it 'does not echo the forged token' do
        request
        expect(response.body).not_to include('forged-token')
      end
    end

    it 'does not include any phone number in the 202 body' do
      request
      expect(response).to have_http_status(:accepted)
      expect(response.body).not_to match(/2015550123|2015550124/)
    end
  end
end
