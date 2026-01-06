# frozen_string_literal: true

RSpec.describe CsvJob::Answers, type: :job do
  subject { described_class.perform_now(user.id, intervention.id, requested_at, period_of_time_params) }

  let(:requested_at) { Time.current }
  let(:intervention) { create(:intervention) }
  let(:period_of_time_params) { {} }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  context 'email notifications enabled' do
    let!(:user) { create(:user, :confirmed, :researcher) }

    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'email notifications disabled' do
    let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

    it "Don't send email" do
      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  describe '#safe_parse' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:job_instance) { described_class.new }

    context 'with valid datetime string and timezone' do
      it 'parses datetime in Europe/Warsaw timezone' do
        result = job_instance.send(:safe_parse, '2024-01-15 10:30:00', 'Europe/Warsaw')
        expect(result).to be_a(ActiveSupport::TimeWithZone)
        expect(result.zone).to eq('CET')
        expect(result.in_time_zone('Europe/Warsaw').hour).to eq(10)
      end
    end

    context 'with blank datetime string' do
      it 'returns nil for nil input' do
        result = job_instance.send(:safe_parse, nil, 'UTC')
        expect(result).to be_nil
      end

      it 'returns nil for empty string' do
        result = job_instance.send(:safe_parse, '', 'UTC')
        expect(result).to be_nil
      end
    end

    context 'with invalid datetime string' do
      it 'returns nil and handles StandardError' do
        result = job_instance.send(:safe_parse, 'invalid-date', 'UTC')
        expect(result).to be_nil
      end

      it 'returns nil for malformed datetime' do
        result = job_instance.send(:safe_parse, '2024-13-99 99:99:99', 'UTC')
        expect(result).to be_nil
      end
    end

    context 'with default timezone' do
      it 'uses UTC as default timezone when not provided' do
        result = job_instance.send(:safe_parse, '2024-01-15 10:30:00')
        expect(result).to be_a(ActiveSupport::TimeWithZone)
        expect(result.zone).to eq('UTC')
      end
    end

    context 'with ISO 8601 format' do
      it 'parses ISO 8601 datetime string' do
        result = job_instance.send(:safe_parse, '2024-01-15T10:30:00Z', 'UTC')
        expect(result).to be_a(ActiveSupport::TimeWithZone)
        expect(result.strftime('%Y-%m-%d %H:%M:%S')).to eq('2024-01-15 10:30:00')
      end
    end
  end

  describe '#define_period_of_time' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:job_instance) { described_class.new }
    let(:start_time) { Time.zone.parse('2024-01-01 00:00:00') }
    let(:end_time) { Time.zone.parse('2024-01-31 23:59:59') }

    context 'with both start and end datetime' do
      it 'returns a closed range' do
        result = job_instance.send(:define_period_of_time, start_time, end_time)
        expect(result).to be_a(Range)
        expect(result.begin).to eq(start_time)
        expect(result.end).to eq(end_time)
        expect(result.exclude_end?).to be false
      end
    end

    context 'with only start datetime' do
      it 'returns an endless range' do
        result = job_instance.send(:define_period_of_time, start_time, nil)
        expect(result).to be_a(Range)
        expect(result.begin).to eq(start_time)
        expect(result.end).to be_nil
        expect(result.exclude_end?).to be true
      end
    end

    context 'with only end datetime' do
      it 'returns a range from epoch to end datetime' do
        result = job_instance.send(:define_period_of_time, nil, end_time)
        expect(result).to be_a(Range)
        expect(result.begin).to eq(Time.zone.at(0))
        expect(result.end).to eq(end_time)
        expect(result.exclude_end?).to be false
      end
    end

    context 'with neither start nor end datetime' do
      it 'returns nil' do
        result = job_instance.send(:define_period_of_time, nil, nil)
        expect(result).to be_nil
      end
    end
  end

  describe '#suffix_filename' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:job_instance) { described_class.new }
    let(:start_time) { Time.zone.parse('2024-01-01 10:30:00') }
    let(:end_time) { Time.zone.parse('2024-01-31 15:45:00') }

    context 'with both start and end datetime' do
      it 'returns formatted range suffix' do
        result = job_instance.send(:suffix_filename, start_time, end_time)
        expect(result).to eq('2024-01-01-10-30_to_2024-01-31-15-45')
      end
    end

    context 'with only start datetime' do
      it 'returns "from onwards" suffix' do
        result = job_instance.send(:suffix_filename, start_time, nil)
        expect(result).to eq('from_2024-01-01-10-30_onwards')
      end
    end

    context 'with only end datetime' do
      it 'returns "up to" suffix' do
        result = job_instance.send(:suffix_filename, nil, end_time)
        expect(result).to eq('up_to_2024-01-31-15-45')
      end
    end

    context 'with neither start nor end datetime' do
      it 'returns "full export" suffix' do
        result = job_instance.send(:suffix_filename, nil, nil)
        expect(result).to eq('full_export')
      end
    end
  end

  describe 'integration with period_of_time_params' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:session) { create(:session, intervention: intervention) }
    let(:question_group) { create(:question_group, session: session) }
    let(:question) { create(:question_single, question_group: question_group) }

    before do
      # Create user sessions at different times by setting created_at directly
      user_session1 = create(:user_session, session: session, created_at: Time.zone.parse('2024-01-15 10:00:00'))
      create(:answer_single, question: question, user_session: user_session1)

      user_session2 = create(:user_session, session: session, created_at: Time.zone.parse('2024-02-15 10:00:00'))
      create(:answer_single, question: question, user_session: user_session2)

      user_session3 = create(:user_session, session: session, created_at: Time.zone.parse('2024-03-15 10:00:00'))
      create(:answer_single, question: question, user_session: user_session3)
    end

    context 'with date range filtering' do
      let(:period_of_time_params) do
        {
          start_datetime: '2024-02-01 00:00:00',
          end_datetime: '2024-02-28 23:59:59',
          timezone: 'UTC'
        }
      end

      it 'generates CSV with filtered data' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        expect(intervention.reports).to be_attached
      end

      it 'includes correct filename suffix' do
        subject
        latest_report = intervention.reports.attachments.last
        expect(latest_report.filename.to_s).to include('2024-02-01-00-00_to_2024-02-28-23-59')
      end
    end

    context 'with start datetime only' do
      let(:period_of_time_params) do
        {
          start_datetime: '2024-02-01 00:00:00',
          timezone: 'UTC'
        }
      end

      it 'generates CSV with data from start date onwards' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        latest_report = intervention.reports.attachments.last
        expect(latest_report.filename.to_s).to include('from_2024-02-01-00-00_onwards')
      end
    end

    context 'with end datetime only' do
      let(:period_of_time_params) do
        {
          end_datetime: '2024-02-28 23:59:59',
          timezone: 'UTC'
        }
      end

      it 'generates CSV with data up to end date' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        latest_report = intervention.reports.attachments.last
        expect(latest_report.filename.to_s).to include('up_to_2024-02-28-23-59')
      end
    end

    context 'with different timezone' do
      let(:period_of_time_params) do
        {
          start_datetime: '2024-01-15 10:00:00',
          end_datetime: '2024-02-15 10:00:00',
          timezone: 'America/New_York'
        }
      end

      it 'correctly handles timezone conversion' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
      end
    end

    context 'without period_of_time_params' do
      let(:period_of_time_params) { {} }

      it 'generates full export' do
        expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
        latest_report = intervention.reports.attachments.last
        expect(latest_report.filename.to_s).to include('full_export')
      end
    end
  end
end
