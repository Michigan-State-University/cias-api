# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::RenderBody
  INSERT_BATCH_SIZE = 5_000
  ROUNDS = SmsLinksUser.slug_rounds

  def self.prepare_links(campaign, recipients)
    new(campaign).prepare_links(recipients)
  end

  def self.call(campaign, pup, links)
    new(campaign).call(pup, links)
  end

  def initialize(campaign)
    @campaign = campaign
  end

  def call(pup, links)
    body = sms_links.reduce(campaign.body) do |text, link|
      text.gsub(SmsLink.token(link.variable)) { SmsLinksUser.tracked_link(links.fetch([link.id, pup.user_id])) }
    end
    "#{body}\n#{PredefinedUserParameter.personal_link(pup.slug)}"
  end

  def prepare_links(recipients)
    return {} if sms_links.empty?

    link_ids = sms_links.map(&:id)
    wanted = link_ids.product(recipients.pluck(:user_id))
    slugs = existing_slugs(link_ids)
    ROUNDS.times do |round|
      missing = wanted - slugs.keys
      return slugs.slice(*wanted) if missing.empty?

      insert_missing(missing, slugs, round)
      slugs = existing_slugs(link_ids) if (wanted - slugs.keys).any?
    end
    return slugs.slice(*wanted) if (wanted - slugs.keys).empty?

    raise CappedSlug::Exhausted, 'SmsLinksUser slug space exhausted'
  end

  private

  attr_reader :campaign

  def sms_links
    @sms_links ||= campaign.sms_links.to_a
  end

  def existing_slugs(link_ids)
    SmsLinksUser.where(sms_link_id: link_ids).pluck(:sms_link_id, :user_id, :slug).to_h do |link_id, user_id, slug|
      [[link_id, user_id], slug]
    end
  end

  def insert_missing(missing, slugs, round)
    used = slugs.values.to_set
    length = SmsLinksUser.slug_length_for_round(round)
    missing.each_slice(INSERT_BATCH_SIZE) do |batch|
      rows = batch.map do |link_id, user_id|
        slug = SecureRandom.base58(length)
        slug = SecureRandom.base58(length) while used.include?(slug)
        used << slug
        { sms_link_id: link_id, user_id: user_id, slug: slug }
      end
      inserted = SmsLinksUser.insert_all(rows, returning: %i[sms_link_id user_id slug]) # rubocop:disable Rails/SkipsModelValidations
      inserted.rows.each { |link_id, user_id, slug| slugs[[link_id, user_id]] = slug }
    end
  end
end
