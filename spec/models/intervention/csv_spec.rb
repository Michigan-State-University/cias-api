# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Intervention::Csv do
  describe 'CSV export sms_links loading' do
    def sms_link_query_count(plan_count)
      intervention = create(:intervention)
      session = create(:session, intervention: intervention)
      create_list(:sms_plan, plan_count, session: session).each do |plan|
        create(:sms_link, session: session, sms_plan: plan)
      end

      count = 0
      subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        count += 1 if payload[:sql] =~ /\ASELECT/i && payload[:sql] =~ /FROM\s+["`]?sms_links["`]?/i
      end
      described_class.new(intervention, nil).send(:collect_data)
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    it 'does not scale sms_links queries with the number of plans' do
      expect(sms_link_query_count(5)).to eq(sms_link_query_count(1))
    end
  end
end
