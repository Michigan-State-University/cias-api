# frozen_string_literal: true

# The dimension under test gets a limit of 2 and the others HIGH_LIMIT, so a 429 can only come from that dimension.
RSpec.describe 'SMS campaign endpoints throttling', type: :request do
  let(:researcher) { campaign_researcher }
  let(:other_researcher) { campaign_researcher }
  let(:intervention) { create(:intervention, :published, user: researcher) }
  let(:ip_a) { '10.20.30.1' }
  let(:ip_b) { '10.20.30.2' }
  let(:high) { SmsCampaignTestHelpers::HIGH_LIMIT }

  around { |example| with_real_rack_attack_store { example.run } }

  def owned_intervention_id
    create(:intervention, :published, user: researcher).id
  end

  def call_endpoint(endpoint, user:, intervention_id:, ip:)
    headers = user.create_new_auth_token.merge('REMOTE_ADDR' => ip)
    case endpoint
    when :create
      post sms_campaigns_api_path(intervention_id),
           params: { sms_campaign: { kind: 'invitation', body: SmsCampaignTestHelpers::CANARY_BODY } }, headers: headers, as: :json
    when :cancel
      post sms_campaigns_api_path(intervention_id, "#{SecureRandom.uuid}/cancel"), headers: headers, as: :json
    end
    response.status
  end

  def limits(dimension, value)
    base = { ip: high, user: high, intervention: high }.merge(dimension => value)
    base.transform_keys { |dim| SmsCampaignTestHelpers::SETTING_KEYS.fetch(:"throttle_#{dim}") }
  end

  def expect_throttled
    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers['Retry-After']).to be_present
    expect(response.headers['Retry-After'].to_i).to be_positive
  end

  %i[create cancel].each do |endpoint|
    describe "POST #{endpoint}" do
      it "requests within the per-IP limit pass, the next one from the same IP is 429 with Retry-After (#{endpoint})" do
        with_sms_campaign_settings(limits(:ip, 2)) do
          freeze_time do
            statuses = Array.new(2) { call_endpoint(endpoint, user: researcher, intervention_id: intervention.id, ip: ip_a) }
            expect(statuses).to all(satisfy { |status| status != 429 })

            call_endpoint(endpoint, user: researcher, intervention_id: intervention.id, ip: ip_a)
            expect_throttled

            expect(call_endpoint(endpoint, user: researcher, intervention_id: intervention.id, ip: ip_b)).not_to eq(429)
          end
        end
      end

      it "the per-IP counter resets after the window (#{endpoint})" do
        with_sms_campaign_settings(limits(:ip, 1)) do
          freeze_time do
            call_endpoint(endpoint, user: researcher, intervention_id: intervention.id, ip: ip_a)
            call_endpoint(endpoint, user: researcher, intervention_id: intervention.id, ip: ip_a)
            expect_throttled
          end
          travel 2.hours do
            expect(call_endpoint(endpoint, user: researcher, intervention_id: intervention.id, ip: ip_a)).not_to eq(429)
          end
        end
      end

      it "requests within the per-user limit pass, the next one by the same user is 429 with Retry-After (#{endpoint})" do
        with_sms_campaign_settings(limits(:user, 2)) do
          freeze_time do
            statuses = Array.new(2) do |i|
              call_endpoint(endpoint, user: researcher, intervention_id: owned_intervention_id, ip: "10.20.31.#{i + 1}")
            end
            expect(statuses).to all(satisfy { |status| status != 429 })

            call_endpoint(endpoint, user: researcher, intervention_id: owned_intervention_id, ip: '10.20.32.1')
            expect_throttled

            expect(call_endpoint(endpoint, user: other_researcher, intervention_id: intervention.id, ip: '10.20.32.1')).not_to eq(429)
          end
        end
      end

      it "requests within the per-intervention limit pass, the next one for the same intervention is 429 with Retry-After (#{endpoint})" do
        with_sms_campaign_settings(limits(:intervention, 2)) do
          freeze_time do
            statuses = Array.new(2) do |i|
              call_endpoint(endpoint, user: create(:user, :admin, :confirmed), intervention_id: intervention.id,
                                      ip: "10.20.33.#{i + 1}")
            end
            expect(statuses).to all(satisfy { |status| status != 429 })

            call_endpoint(endpoint, user: create(:user, :admin, :confirmed), intervention_id: intervention.id, ip: '10.20.34.1')
            expect_throttled

            expect(call_endpoint(endpoint, user: researcher, intervention_id: SecureRandom.uuid, ip: '10.20.34.1')).not_to eq(429)
          end
        end
      end
    end
  end

  describe 'POST create (per-intervention counter is independent of the caller)' do
    it 'counts the intervention regardless of who calls (another user hits the same limit)' do
      with_sms_campaign_settings(limits(:intervention, 2)) do
        freeze_time do
          2.times do |i|
            call_endpoint(:create, user: researcher, intervention_id: intervention.id, ip: "10.20.35.#{i + 1}")
          end

          call_endpoint(:create, user: create(:user, :admin, :confirmed), intervention_id: intervention.id, ip: '10.20.36.1')
          expect_throttled
        end
      end
    end
  end

  describe 'POST create (requests refused by authorization are not counted)' do
    it 'an outsider does not consume the intervention limit of its editors' do
      with_sms_campaign_settings(limits(:intervention, 2)) do
        freeze_time do
          statuses = Array.new(2) do |i|
            call_endpoint(:create, user: other_researcher, intervention_id: intervention.id, ip: "10.20.37.#{i + 1}")
          end
          expect(statuses).to all(eq(404))

          expect(call_endpoint(:create, user: researcher, intervention_id: intervention.id, ip: '10.20.38.1')).not_to eq(429)
        end
      end
    end
  end
end
