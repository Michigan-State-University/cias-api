# frozen_string_literal: true

RSpec.describe 'chart_statistics:regenerate' do
  subject(:invoke) { Rake::Task['chart_statistics:regenerate'].invoke }

  let!(:organization) { create(:organization) }
  let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let!(:chart) { create(:chart, dashboard_section: dashboard_section, chart_type: 'bar_chart', status: 'published') }

  let(:env_keys) { %w[CHART_IDS REPLACE CONFIRM] }
  let(:original_env) { env_keys.index_with { |key| ENV.fetch(key, nil) } }

  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['chart_statistics:regenerate'].reenable
    original_env
    env_keys.each { |key| ENV.delete(key) }
    allow(V1::Charts::Regenerate).to receive(:call)
  end

  after { original_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value } }

  context 'without CHART_IDS' do
    it 'aborts without calling the service' do
      expect { invoke }.to raise_error(SystemExit)
      expect(V1::Charts::Regenerate).not_to have_received(:call)
    end
  end

  context 'with an unknown chart id' do
    before { ENV['CHART_IDS'] = SecureRandom.uuid }

    it 'aborts without calling the service' do
      expect { invoke }.to raise_error(SystemExit)
      expect(V1::Charts::Regenerate).not_to have_received(:call)
    end
  end

  # The guard that matters: REPLACE destroys every row for the chart before replaying, and the
  # replay cannot recreate rows whose originating session no longer matches the formula. Running
  # it unconfirmed would be silent, unrecoverable data loss.
  context 'in REPLACE mode without CONFIRM' do
    before { ENV['CHART_IDS'] = chart.id }

    it 'aborts without calling the service' do
      expect { invoke }.to raise_error(SystemExit)
      expect(V1::Charts::Regenerate).not_to have_received(:call)
    end
  end

  context 'in REPLACE mode with CONFIRM=yes' do
    before do
      ENV['CHART_IDS'] = chart.id
      ENV['CONFIRM'] = 'yes'
    end

    it 'calls the service with replace enabled' do
      expect { invoke }.to output(/will be DESTROYED and replayed/).to_stdout
      expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: true)
    end
  end

  # The "safe" path is not read-only - the replay still upserts, and on a legacy `min == 0` chart
  # the de-dup key includes `label`, so a participant can gain a second row. Hence CONFIRM guards
  # both paths.
  context 'with REPLACE=false and no CONFIRM' do
    before do
      ENV['CHART_IDS'] = chart.id
      ENV['REPLACE'] = 'false'
    end

    it 'still aborts, because the replay can add rows' do
      expect { invoke }.to raise_error(SystemExit)
      expect(V1::Charts::Regenerate).not_to have_received(:call)
    end
  end

  context 'with REPLACE=false and CONFIRM=yes' do
    before do
      ENV['CHART_IDS'] = chart.id
      ENV['REPLACE'] = 'false'
      ENV['CONFIRM'] = 'yes'
    end

    it 'calls the service without destroying' do
      expect { invoke }.to output(/no rows are destroyed/).to_stdout
      expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: false)
    end
  end

  # None of these may silently select the DESTRUCTIVE path. `f` and `n` are the two spellings the
  # original denylist read as "yes, destroy".
  %w[False FALSE 0 no n f off].each do |falsey|
    context "with REPLACE=#{falsey}" do
      before do
        ENV['CHART_IDS'] = chart.id
        ENV['REPLACE'] = falsey
        ENV['CONFIRM'] = 'yes'
      end

      it 'is treated as non-destructive' do
        expect { invoke }.to output(/no rows are destroyed/).to_stdout
        expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: false)
      end
    end
  end

  # The guard Finding 4 added: a value in neither allow-list must abort rather than fall through
  # to `destroy_all`. `n` and `f` are covered by the falsey loop above; these are the true unknowns.
  %w[nope maybe -1].each do |garbage|
    context "with REPLACE=#{garbage}" do
      before do
        ENV['CHART_IDS'] = chart.id
        ENV['REPLACE'] = garbage
        ENV['CONFIRM'] = 'yes'
      end

      it 'aborts without calling the service' do
        expect { invoke }.to raise_error(SystemExit)
        expect(V1::Charts::Regenerate).not_to have_received(:call)
      end
    end
  end

  # A present-but-empty REPLACE never reaches `ENV.fetch`'s default, so it used to resolve
  # destructive; it is now an unrecognised value like any other.
  context 'with REPLACE set to an empty string' do
    before do
      ENV['CHART_IDS'] = chart.id
      ENV['REPLACE'] = ''
      ENV['CONFIRM'] = 'yes'
    end

    it 'aborts without calling the service' do
      expect { invoke }.to raise_error(SystemExit)
      expect(V1::Charts::Regenerate).not_to have_received(:call)
    end
  end

  context 'with a mixed-case chart id' do
    before do
      ENV['CHART_IDS'] = chart.id.upcase
      ENV['CONFIRM'] = 'yes'
    end

    it 'normalises rather than aborting for a chart that exists' do
      expect { invoke }.to output(/will be DESTROYED/).to_stdout
      expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: true)
    end
  end

  context 'with a draft chart' do
    let!(:draft_chart) { create(:chart, dashboard_section: dashboard_section, chart_type: 'bar_chart', status: 'draft') }

    before do
      ENV['CHART_IDS'] = draft_chart.id
      ENV['CONFIRM'] = 'yes'
    end

    it 'refuses to materialise statistics for a chart that never collected' do
      expect { invoke }.to raise_error(SystemExit)
      expect(V1::Charts::Regenerate).not_to have_received(:call)
    end
  end
end
