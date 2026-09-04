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

  describe '.excluding_insufficient_data' do
    let!(:real_row) { create(:chart_statistic, label: 'Matched') }
    let!(:invalid_row) { create(:chart_statistic, label: described_class::INSUFFICIENT_DATA_LABEL) }
    let!(:unlabelled_row) { create(:chart_statistic, label: nil) }

    it 'drops only the reserved label' do
      expect(described_class.excluding_insufficient_data).not_to include(invalid_row)
      expect(described_class.excluding_insufficient_data).to include(real_row)
    end

    it 'keeps a NULL-labelled row' do
      # `where.not(label: ...)` alone would silently drop these (SQL `NULL <> 'x'` is NULL,
      # not true), and a NULL label is reachable: a pattern with no `label` key is
      # schema-valid, so such rows exist and must keep counting on the bar charts.
      expect(described_class.excluding_insufficient_data).to include(unlabelled_row)
    end

    it "does not widen the caller's scope" do
      # Production never calls this on the bare class: `BarChart#initialize` applies it to the
      # controller's already-authorized relation. `Relation#or` is safe here ONLY because the
      # argument is built from the same relation, so Rails factors the caller's predicates into
      # `common` (where_clause.rb:36-59) instead of pushing them into one OR branch. Rewritten as
      # `ChartStatistic.where(label: nil)` or `unscoped.where(label: nil)` - both of which read as
      # harmless "be explicit" tidy-ups - `common` computes empty and the SQL becomes
      # `(<base> AND label <> '...') OR label IS NULL`, admitting every NULL-labelled row in every
      # organization. The factory associates a fresh organization per row, so these three sit in
      # three different organizations.
      scoped = described_class.where(organization_id: real_row.organization_id).excluding_insufficient_data

      expect(scoped).to include(real_row)
      expect(scoped).not_to include(invalid_row)
      # Excluded because it belongs to a DIFFERENT organization, not because its label is NULL.
      expect(scoped).not_to include(unlabelled_row)
    end
  end
end
