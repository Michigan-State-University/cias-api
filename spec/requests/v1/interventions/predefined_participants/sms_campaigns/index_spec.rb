# frozen_string_literal: true

require 'rails_helper'
require 'support/predefined_participant_sms_helpers'

RSpec.describe 'GET /v1/interventions/:intervention_id/predefined_participants/sms_campaigns', type: :request do
  include PredefinedParticipantSmsHelpers

  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let!(:intervention) { create(:intervention, :published, user: researcher) }
  let(:path) { "/v1/interventions/#{intervention.id}/predefined_participants/sms_campaigns" }
  let(:request) { get path, headers: current_user.create_new_auth_token }
  let(:provisional_flag) { 'scheduled_at_provisional' }

  def ids
    json_response['data'].pluck('id')
  end

  def insert_closed_campaigns(target, count, start: Time.zone.parse('2026-01-01 00:00:00'))
    rows = Array.new(count) do |i|
      { intervention_id: target.id, kind: 'invitation', status: 'sent', body: canary_body, scheduled_at: start + i.minutes,
        created_at: start + i.minutes, updated_at: start + i.minutes }
    end
    PredefinedParticipants::SmsCampaign.insert_all(rows)
  end

  describe 'paginated list' do
    it 'answers 200 with the campaigns of the intervention' do
      create(:pdp_sms_campaign, intervention: intervention, status: 'sent')
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(1)
    end

    it 'answers 200 with an empty list when the intervention has no campaigns' do
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end

    it 'does not return the whole collection when per_page is omitted' do
      insert_closed_campaigns(intervention, 300)
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to be_between(1, 299)
    end

    it 'honours an explicit per_page' do
      insert_closed_campaigns(intervention, 7)
      get path, params: { per_page: 3 }, headers: researcher.create_new_auth_token
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(3)
    end

    it 'serves disjoint pages that together follow the created_at descending order' do
      insert_closed_campaigns(intervention, 7)
      expected = PredefinedParticipants::SmsCampaign.where(intervention_id: intervention.id).order(created_at: :desc).pluck(:id)
      get path, params: { per_page: 3, page: 1 }, headers: researcher.create_new_auth_token
      expect(response).to have_http_status(:ok)
      first_page = ids
      get path, params: { per_page: 3, page: 2 }, headers: researcher.create_new_auth_token
      expect(response).to have_http_status(:ok)
      expect(first_page + ids).to eq(expected.first(6))
    end

    it 'exposes the stored counters and timestamps of a finished campaign' do
      sent_at = Time.zone.parse('2026-10-29 12:30:00')
      campaign = create(:pdp_sms_campaign, intervention: intervention, status: 'sent', sent_at: sent_at,
                                           recipients_count: 5, accepted_count: 4, failed_count: 1)
      request
      expect(response).to have_http_status(:ok)
      attributes = json_response['data'].sole['attributes']
      expect(json_response['data'].sole['id']).to eq(campaign.id)
      expect(attributes).to include('kind' => 'invitation', 'status' => 'sent', 'recipients_count' => 5, 'accepted_count' => 4,
                                    'failed_count' => 1)
      expect(Time.zone.parse(attributes['sent_at'])).to be_within(1.second).of(sent_at)
    end

    it 'never exposes the stored body' do
      create(:pdp_sms_campaign, intervention: intervention, status: 'sent')
      request
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(canary_body)
    end

    it 'is not answered by predefined_participants#show' do
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
    end
  end

  describe 'scope and ordering' do
    it 'orders campaigns by created_at descending' do
      oldest = create(:pdp_sms_campaign, intervention: intervention, status: 'sent', created_at: Time.zone.parse('2026-10-27 12:00:00'))
      middle = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'failed',
                                         created_at: Time.zone.parse('2026-10-28 12:00:00'))
      newest = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sent',
                                         created_at: Time.zone.parse('2026-10-29 12:00:00'))
      request
      expect(response).to have_http_status(:ok)
      expect(ids).to eq([newest.id, middle.id, oldest.id])
    end

    it 'does not return campaigns of another intervention of the same researcher' do
      own = create(:pdp_sms_campaign, intervention: intervention, status: 'sent')
      sibling = create(:intervention, :published, user: researcher)
      foreign = create(:pdp_sms_campaign, intervention: sibling, status: 'sent')
      request
      expect(response).to have_http_status(:ok)
      expect(ids).to eq([own.id])
      expect(ids).not_to include(foreign.id)
    end

    it 'does not return campaigns of an intervention owned by someone else' do
      foreign = create(:pdp_sms_campaign, status: 'sent')
      create(:pdp_sms_campaign, intervention: intervention, status: 'sent')
      request
      expect(response).to have_http_status(:ok)
      expect(ids).not_to include(foreign.id)
      expect(ids.size).to eq(1)
    end

    it 'lists every kind together' do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent')
      create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', status: 'sent')
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['attributes']['kind'] }).to match_array(%w[invitation manual_reminder])
    end
  end

  describe 'provisional flag in the list' do
    it 'marks a scheduled reminder whose parent is still in flight as provisional' do
      parent = create(:pdp_sms_campaign, intervention: intervention, status: 'sending')
      child = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: parent, days_after: 3)
      request
      expect(response).to have_http_status(:ok)
      row = json_response['data'].find { |entry| entry['id'] == child.id }
      expect(row['attributes'][provisional_flag]).to be(true)
    end

    it 'does not mark the parent invitation as provisional' do
      parent = create(:pdp_sms_campaign, intervention: intervention, status: 'sending')
      create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', parent_campaign: parent, days_after: 3)
      request
      expect(response).to have_http_status(:ok)
      row = json_response['data'].find { |entry| entry['id'] == parent.id }
      expect(row['attributes'][provisional_flag]).to be(false)
    end
  end

  describe 'no N+1' do
    def build_pairs(target, count)
      count.times do |i|
        parent = create(:pdp_sms_campaign, intervention: target, status: 'sent', sent_at: Time.zone.parse('2026-10-29 12:00:00'),
                                           created_at: Time.zone.parse('2026-10-20 12:00:00') + i.hours)
        create(:pdp_sms_campaign, intervention: target, kind: 'scheduled_reminder', parent_campaign: parent, days_after: 3,
                                  created_at: Time.zone.parse('2026-10-20 12:30:00') + i.hours)
        participant = make_participant(target, index: i)
        create(:pdp_sms_delivery, campaign: parent, predefined_user_parameter: participant, status: 'sent')
      end
    end

    let(:small) { create(:intervention, :published, user: researcher) }
    let(:large) { create(:intervention, :published, user: researcher) }

    def measured_get(target)
      headers = researcher.create_new_auth_token
      count_queries do
        get "/v1/interventions/#{target.id}/predefined_participants/sms_campaigns", headers: headers
      end
    end

    it 'does not grow the number of SQL queries with the number of campaigns on the page' do
      build_pairs(small, 1)
      build_pairs(large, 5)
      measured_get(small)
      small_count = measured_get(small)
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(2)
      large_count = measured_get(large)
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].size).to eq(10)
      expect(large_count).to eq(small_count)
    end

    it 'returns a null recipients_count for a campaign that has not started, with no per-row forecast' do
      make_participant(intervention, index: 0)
      make_participant(intervention, index: 1)
      campaign = create(:pdp_sms_campaign, intervention: intervention, status: 'scheduled')
      headers = researcher.create_new_auth_token
      queries = collect_queries { get path, headers: headers }
      expect(response).to have_http_status(:ok)
      row = json_response['data'].find { |entry| entry['id'] == campaign.id }
      expect(row['attributes']['recipients_count']).to be_nil
      expect(queries.grep(/predefined_user_parameters|"phones"/)).to be_empty
    end

    it 'does not count deliveries per row' do
      build_pairs(large, 5)
      headers = researcher.create_new_auth_token
      queries = collect_queries { get "/v1/interventions/#{large.id}/predefined_participants/sms_campaigns", headers: headers }
      expect(response).to have_http_status(:ok)
      expect(queries.grep(/COUNT\(.*\).*predefined_participants_sms_deliveries/m).size).to be <= 1
    end
  end

  describe 'gates' do
    it 'answers 401 without a token' do
      get path
      expect(response).to have_http_status(:unauthorized)
    end

    it_behaves_like 'users without access'

    context 'with a collaborator who has edit: true' do
      let(:collaborator) { create(:user, :researcher, :confirmed) }

      before do
        create(:collaborator, intervention: intervention, user: collaborator, edit: true, view: true)
      end

      it 'answers 403 when the collaborator is not the current editor' do
        intervention.update!(current_editor: researcher)
        get path, headers: collaborator.create_new_auth_token
        expect(response).to have_http_status(:forbidden)
      end

      it 'the same collaborator gets 200 once they are the current editor' do
        intervention.update!(current_editor: collaborator)
        get path, headers: collaborator.create_new_auth_token
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'ordering, scoping and payload' do
    def response_ids
      expect(response).to have_http_status(:ok)
      json_response['data'].pluck('id')
    end

    it 'lists a scheduled_reminder child together with its parent' do
      parent = create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'sent',
                                         created_at: Time.zone.parse('2026-10-01 10:00:00'))
      child = create(:pdp_sms_campaign, intervention: intervention, kind: 'scheduled_reminder', status: 'scheduled',
                                        parent_campaign: parent, days_after: 3, created_at: Time.zone.parse('2026-10-01 10:00:01'))
      request
      expect(response_ids).to eq([child.id, parent.id])
      expect(json_response['data'].find { |row| row['id'] == child.id }['attributes']['kind']).to eq('scheduled_reminder')
    end

    it 'returns the stored counters untouched' do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'failed', recipients_count: 7,
                                accepted_count: 5, failed_count: 2)
      request
      expect(response).to have_http_status(:ok)
      expect(json_response['data'].sole['attributes']).to include('recipients_count' => 7, 'accepted_count' => 5,
                                                                  'failed_count' => 2)
    end

    it 'builds no per-row recipient forecast (no query touches participants, phones or opt-outs)' do
      create(:pdp_sms_campaign, intervention: intervention, kind: 'invitation', status: 'scheduled')
      insert_closed_campaigns(intervention, 4)
      headers = researcher.create_new_auth_token
      queries = collect_queries { get path, headers: headers }
      expect(response).to have_http_status(:ok)
      expect(queries.grep(/predefined_user_parameters|sms_opt_outs|"phones"/)).to be_empty
    end

    it 'answers 401 for a forged token' do
      get path, headers: { 'access-token' => 'forged', 'client' => 'forged', 'uid' => researcher.email }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not disclose any campaign to another researcher' do
      insert_closed_campaigns(intervention, 1)
      other = create(:user, :researcher, :confirmed)
      get path, headers: other.create_new_auth_token
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(canary_body)
    end
  end
end
