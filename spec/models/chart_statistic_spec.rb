# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChartStatistic, type: :model do
  it { should belong_to(:organization) }
  it { should belong_to(:health_system) }
  it { should belong_to(:health_clinic) }
  it { should belong_to(:user) }

  describe 'callback methods' do
    let!(:chart_statistic) { create(:chart_statistic) }

    it 'sets filled_at date when it is null' do
      chart_statistic.filled_at = nil
      chart_statistic.save!
      expect(chart_statistic.filled_at).not_to be_nil
    end

    it 'does not change the date when it is not null' do
      chart_statistic.filled_at = DateTime.current - 1.year
      chart_statistic.save!
      expect(chart_statistic.filled_at).not_to eq chart_statistic.created_at
    end
  end
end
