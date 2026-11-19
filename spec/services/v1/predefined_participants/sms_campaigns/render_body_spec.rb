# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::PredefinedParticipants::SmsCampaigns::RenderBody' do
  context 'with one tracked link and two participants' do
    include PredefinedParticipantSmsHelpers

    let(:intervention) { create(:intervention, :published) }
    let(:campaign) { create(:pdp_sms_campaign, intervention: intervention, body: "#{canary_body} ::#{canary_variable}::") }
    let!(:link) { create(:pdp_campaign_sms_link, campaign: campaign, variable: canary_variable, url: canary_url) }
    let!(:pup_one) { make_participant(intervention, index: 0) }
    let!(:pup_two) { make_participant(intervention, index: 1) }

    before { travel_to(frozen_now) }

    def render_class
      V1::PredefinedParticipants::SmsCampaigns::RenderBody
    end

    def recipients_relation(scope_intervention = intervention)
      PredefinedUserParameter.where(intervention_id: scope_intervention.id).includes(user: :phone)
    end

    def tracked_slug_for(sms_link, pup)
      SmsLinksUser.find_by!(sms_link_id: sms_link.id, user_id: pup.user_id).slug
    end

    describe 'call renders one body' do
      it 'substitutes the tracked variable with WEB_URL/link/<slug> and appends the personal link on a new line' do
        links = { [link.id, pup_one.user_id] => canary_slug }
        expected = "#{canary_body} #{web_url}/link/#{canary_slug}\n#{web_url}/usr/#{pup_one.slug}"
        expect(render_class.call(campaign, pup_one, links)).to eq(expected)
      end

      it 'uses the slug of the given participant and not the slug of another one' do
        links = { [link.id, pup_one.user_id] => canary_slug, [link.id, pup_two.user_id] => 'ciastddothersluge' }
        body = render_class.call(campaign, pup_two, links)
        expect(body).to include("/link/ciastddothersluge\n#{web_url}/usr/#{pup_two.slug}")
        expect(body).not_to include(canary_slug)
      end

      it 'leaves no ::variable:: placeholder behind and replaces every occurrence' do
        campaign.update!(body: "::#{canary_variable}:: and ::#{canary_variable}::")
        links = { [link.id, pup_one.user_id] => canary_slug }
        body = render_class.call(campaign, pup_one, links)
        expect(body).not_to include('::')
        expect(body.scan("/link/#{canary_slug}").size).to eq(2)
      end

      it 'appends only the personal link for a body without variables' do
        plain = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', body: canary_body)
        expect(render_class.call(plain, pup_one, {})).to eq("#{canary_body}\n#{web_url}/usr/#{pup_one.slug}")
      end
    end

    describe 'prepare_links builds all rows before the loop' do
      it 'creates one SmsLinksUser per participant and link and returns the keyed slug map' do
        second_link = create(:pdp_campaign_sms_link, campaign: campaign, variable: 'canary_link_two', url: "#{canary_url}-two")
        map = nil
        expect { map = render_class.prepare_links(campaign, recipients_relation) }.to change(SmsLinksUser, :count).by(4)
        expected_keys = [link, second_link].product([pup_one, pup_two]).map { |sms_link, pup| [sms_link.id, pup.user_id] }
        expect(map.keys).to match_array(expected_keys)
        expect(map).to eq(SmsLinksUser.pluck(:sms_link_id, :user_id, :slug).to_h { |link_id, user_id, slug| [[link_id, user_id], slug] })
      end

      it 'returns distinct base58 slugs inside the capped length' do
        map = render_class.prepare_links(campaign, recipients_relation)
        expect(map.values.uniq.size).to eq(2)
        expect(map.values).to all(match(/\A[1-9A-HJ-NP-Za-km-z]{5,9}\z/))
      end

      it 'returns nothing and creates nothing for a campaign without links' do
        plain = create(:pdp_sms_campaign, intervention: intervention, kind: 'manual_reminder', body: canary_body)
        map = nil
        expect { map = render_class.prepare_links(plain, recipients_relation) }.not_to change(SmsLinksUser, :count)
        expect(map).to eq({})
      end

      it 'feeds call so that the rendered body carries the participant own tracked slug' do
        map = render_class.prepare_links(campaign, recipients_relation)
        body = render_class.call(campaign, pup_two, map)
        expect(body).to include("#{web_url}/link/#{tracked_slug_for(link, pup_two)}")
        expect(body).to end_with("\n#{web_url}/usr/#{pup_two.slug}")
      end

      it 'call does not touch the database once campaign and recipients are loaded' do
        loaded = PredefinedParticipants::SmsCampaign.includes(:sms_links).find(campaign.id)
        loaded_pups = recipients_relation.to_a
        map = render_class.prepare_links(loaded, recipients_relation)
        rendered = nil
        queries = count_queries { rendered = render_class.call(loaded, loaded_pups.first, map) }
        expect(rendered).to include('/link/')
        expect(queries).to eq(0)
      end
    end

    describe 'prepare_links does not issue queries per recipient' do
      def queries_for(count)
        local_intervention = create(:intervention, :published)
        local_campaign = create(:pdp_sms_campaign, intervention: local_intervention, body: "::#{canary_variable}:: ::canary_link_two::")
        create(:pdp_campaign_sms_link, campaign: local_campaign, variable: canary_variable, url: canary_url)
        create(:pdp_campaign_sms_link, campaign: local_campaign, variable: 'canary_link_two', url: "#{canary_url}-two")
        count.times { |index| make_participant(local_intervention, index: index) }
        queries = count_queries { render_class.prepare_links(local_campaign, recipients_relation(local_intervention)) }
        created = SmsLinksUser.where(sms_link_id: local_campaign.sms_links.select(:id)).count
        [queries, created]
      end

      it 'issues the same number of queries for 1 and for 5 recipients with 2 links' do
        queries_for(1)
        one, one_created = queries_for(1)
        five, five_created = queries_for(5)
        expect([one_created, five_created]).to eq([2, 10])
        expect(five).to eq(one)
      end
    end

    describe 'prepare_links is idempotent' do
      it 'a second call returns the same slugs, creates no rows and does not raise' do
        first = render_class.prepare_links(campaign, recipients_relation)
        second = nil
        expect { second = render_class.prepare_links(campaign, recipients_relation) }.not_to change(SmsLinksUser, :count)
        expect(second).to eq(first)
        expect(first.size).to eq(2)
      end

      it 'reuses the slug of an already existing row and creates only the missing one' do
        existing = SmsLinksUser.create!(sms_link: link, user: pup_one.user)
        map = nil
        expect { map = render_class.prepare_links(campaign, recipients_relation) }.to change(SmsLinksUser, :count).by(1)
        expect(map[[link.id, pup_one.user_id]]).to eq(existing.reload.slug)
        expect(map[[link.id, pup_two.user_id]]).to eq(tracked_slug_for(link, pup_two))
      end

      it 'keeps earlier slugs when a later call covers one more participant' do
        first = render_class.prepare_links(campaign, recipients_relation)
        pup_three = make_participant(intervention, index: 2)
        later = render_class.prepare_links(campaign, recipients_relation)
        expect(later.slice(*first.keys)).to eq(first)
        expect(later[[link.id, pup_three.user_id]]).to be_present
      end
    end

    describe 'slugs are issued for participants from both creation paths' do
      it 'prepare_links covers a participant created one by one and one created by bulk import' do
        researcher = create(:user, :researcher, :confirmed)
        single = V1::Intervention::PredefinedParticipants::CreateService.call(
          intervention,
          ActionController::Parameters.new(first_name: 'Single', email: 'render-single@example.test',
                                           phone_attributes: { 'iso' => 'US', 'prefix' => '+1', 'number' => '2015550127' }).permit!
        )
        payload = [{ 'attributes' => { 'first_name' => 'Bulk', 'email' => 'render-bulk@example.test',
                                       'phone_attributes' => { 'iso' => 'US', 'prefix' => '+1', 'number' => '2015550128' } },
                     'variable_answers' => {} }]
        V1::Intervention::PredefinedParticipants::BulkImportService.call(researcher, intervention, payload)
        bulk = User.find_by!(email: 'render-bulk@example.test')
        map = render_class.prepare_links(campaign, recipients_relation)
        expect(map.keys).to include([link.id, single.id], [link.id, bulk.id])
      end
    end
  end

  context 'with two tracked links', type: :service do
    include PredefinedParticipantSmsHelpers

    let(:render_body) { 'V1::PredefinedParticipants::SmsCampaigns::RenderBody'.constantize }
    let(:intervention) { create(:intervention, :published) }
    let(:body) { "#{PredefinedParticipantSmsHelpers::CANARY_BODY} ::canary_link:: and ::canary_link_two::" }
    let(:campaign) { create(:pdp_sms_campaign, intervention: intervention, body: body) }
    let!(:link_one) { create(:pdp_campaign_sms_link, campaign: campaign, variable: 'canary_link', url: 'https://example.test/canary-target-1') }
    let!(:link_two) { create(:pdp_campaign_sms_link, campaign: campaign, variable: 'canary_link_two', url: 'https://example.test/canary-target-2') }

    before { stub_web_url }

    def recipients_for(pups)
      PredefinedUserParameter.where(id: pups.map(&:id)).includes(user: :phone)
    end

    def tracked_slug(link, pup)
      SmsLinksUser.find_by!(sms_link_id: link.id, user_id: pup.user_id).slug
    end

    describe 'rendering one body' do
      let(:pup) { create_participant(intervention) }

      it 'substitutes every ::variable:: with WEB_URL/link/<slug> and appends WEB_URL/usr/<slug> on a new line' do
        links = render_body.prepare_links(campaign, recipients_for([pup]))
        rendered = render_body.call(campaign, pup, links)

        expect(rendered).to eq(
          "#{PredefinedParticipantSmsHelpers::CANARY_BODY} #{PredefinedParticipantSmsHelpers::WEB_URL}/link/#{tracked_slug(link_one, pup)} and " \
          "#{PredefinedParticipantSmsHelpers::WEB_URL}/link/#{tracked_slug(link_two, pup)}\n#{PredefinedParticipantSmsHelpers::WEB_URL}/usr/#{pup.slug}"
        )
        expect(rendered).not_to include('::')
      end

      it 'gives two participants different tracked slugs and each their own personal slug' do
        other = create_participant(intervention)
        links = render_body.prepare_links(campaign, recipients_for([pup, other]))
        first = render_body.call(campaign, pup, links)
        second = render_body.call(campaign, other, links)

        expect(first).to end_with("/usr/#{pup.slug}")
        expect(second).to end_with("/usr/#{other.slug}")
        expect(tracked_slug(link_one, pup)).not_to eq(tracked_slug(link_one, other))
        expect(first).not_to eq(second)
      end

      context 'when the campaign has no links' do
        let(:body) { PredefinedParticipantSmsHelpers::CANARY_BODY }
        let!(:link_one) { nil }
        let!(:link_two) { nil }

        it 'returns the body followed by the personal link only' do
          links = render_body.prepare_links(campaign, recipients_for([pup]))
          expect(render_body.call(campaign, pup, links)).to eq("#{body}\n#{PredefinedParticipantSmsHelpers::WEB_URL}/usr/#{pup.slug}")
          expect(links).to be_empty
        end
      end
    end

    describe 'prepare_links creates the rows in bulk and call does not touch the database' do
      let(:pups) { Array.new(5) { create_participant(intervention) } }

      it 'returns a map keyed by [sms_link_id, user_id] with the slug stored in the database' do
        links = render_body.prepare_links(campaign, recipients_for(pups))

        expected_keys = pups.product([link_one, link_two]).map { |pup, link| [link.id, pup.user_id] }
        expect(links.keys).to match_array(expected_keys)
        links.each do |(sms_link_id, user_id), slug|
          expect(SmsLinksUser.find_by!(sms_link_id: sms_link_id, user_id: user_id).slug).to eq(slug)
        end
        expect(links.values).to all(be_present)
        expect(links.values.uniq.size).to eq(10)
      end

      it 'creates one row per recipient and link' do
        recipients = recipients_for(pups)
        expect { render_body.prepare_links(campaign, recipients) }.to change(SmsLinksUser, :count).by(10)
      end

      it 'writes the rows with a single INSERT statement, not one per recipient' do
        recipients = recipients_for(pups)
        statements = collect_queries { render_body.prepare_links(campaign, recipients) }
        inserts = statements.grep(/INSERT INTO "sms_links_users"/)
        expect(SmsLinksUser.where(sms_link_id: [link_one.id, link_two.id]).count).to eq(10)
        expect(inserts.size).to eq(1)
      end

      it 'renders from the map without a single SQL query' do
        links = render_body.prepare_links(campaign, recipients_for(pups))
        pup = PredefinedUserParameter.find(pups.first.id)
        rendered = nil
        expect(count_queries { rendered = render_body.call(campaign, pup, links) }).to eq(0)
        expect(rendered).to include("#{PredefinedParticipantSmsHelpers::WEB_URL}/usr/#{pup.slug}")
      end
    end

    describe 'the number of queries does not grow with the number of recipients' do
      it 'issues the same number of queries for 1 and for 5 recipients with 2 links' do
        one = Array.new(1) { create_participant(intervention) }
        five = Array.new(5) { create_participant(intervention) }
        recipients_one = recipients_for(one)
        recipients_five = recipients_for(five)

        fresh = -> { PredefinedParticipants::SmsCampaign.find(campaign.id) }
        queries_for_one = count_queries { render_body.prepare_links(fresh.call, recipients_one) }
        queries_for_five = count_queries { render_body.prepare_links(fresh.call, recipients_five) }

        expect(SmsLinksUser.where(sms_link_id: [link_one.id, link_two.id]).count).to eq(12)
        expect(queries_for_five).to eq(queries_for_one)
      end
    end

    describe 'reuse of existing SmsLinksUser rows' do
      let(:pup) { create_participant(intervention) }

      it 'returns the same slugs and creates nothing on a second prepare_links for the same participant' do
        first = render_body.prepare_links(campaign, recipients_for([pup]))
        second = nil
        expect { second = render_body.prepare_links(campaign, recipients_for([pup])) }.not_to change(SmsLinksUser, :count)
        expect(second).to eq(first)
        expect(first.size).to eq(2)
      end

      it 'does not raise on the unique (sms_link_id, user_id) index when rows already exist' do
        SmsLinksUser.create!(sms_link: link_one, user: pup.user)
        existing_slug = SmsLinksUser.find_by!(sms_link_id: link_one.id, user_id: pup.user_id).slug

        links = nil
        expect { links = render_body.prepare_links(campaign, recipients_for([pup])) }.not_to raise_error
        expect(links[[link_one.id, pup.user_id]]).to eq(existing_slug)
        expect(links[[link_two.id, pup.user_id]]).to be_present
        expect(SmsLinksUser.where(user_id: pup.user_id).count).to eq(2)
      end

      it 'renders the same text for a participant on a repeated run (reminder or resend)' do
        first_links = render_body.prepare_links(campaign, recipients_for([pup]))
        first_text = render_body.call(campaign, pup, first_links)
        second_links = render_body.prepare_links(campaign, recipients_for([pup]))
        expect(render_body.call(campaign, pup, second_links)).to eq(first_text)
      end
    end
  end
end
