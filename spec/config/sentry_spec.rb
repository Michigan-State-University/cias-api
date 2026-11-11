# frozen_string_literal: true

# Which request params reach Sentry is decided by config.filter_parameters (config/initializers/filter_parameter_logging.rb),
# as long as send_default_pii stays off.
RSpec.describe Sentry do
  # When it is on, traces carry request.params instead of request.filtered_parameters and error events carry the raw
  # request body, so neither filter below applies.
  describe '.configuration.send_default_pii' do
    it 'is off' do
      expect(described_class.configuration.send_default_pii).to be(false)
    end
  end

  # sentry-rails copies request.filtered_parameters into breadcrumbs and span data. Transactions are sampled at 100%
  # and never pass through before_send, so for them this is the only filter.
  describe 'request params in breadcrumbs and span data' do
    subject(:filtered) { ActionDispatch::Request.new(env).filtered_parameters }

    let(:env) { Rack::MockRequest.env_for('/', method: 'POST', params: params).merge(Rails.application.env_config) }

    context 'with Henry Ford patient verification params' do
      let(:params) do
        {
          'hfhs_patient_data' => {
            'first_name' => 'Jane', 'last_name' => 'Doe', 'dob' => '2015-04-02', 'sex' => 'F', 'zip_code' => '48202',
            'phone_number' => '3135550100', 'phone_type' => 'mobile', 'mrn' => '12345678'
          },
          'session_id' => 'f3b1c2d4'
        }
      end

      it 'masks every patient field' do
        expect(filtered['hfhs_patient_data']).to eq(params['hfhs_patient_data'].transform_values { '[FILTERED]' })
      end

      it 'keeps the session id' do
        expect(filtered['session_id']).to eq('f3b1c2d4')
      end
    end

    context 'with stored Henry Ford patient identifiers' do
      let(:params) do
        { 'patient_id' => 'Z1234', 'visit_id' => 'V5678', 'provided_dob' => '2015-04-02', 'provided_sex' => 'F', 'provided_zip' => '48202',
          'provided_phone_type' => 'mobile' }
      end

      it 'masks them' do
        expect(filtered.values).to all(eq('[FILTERED]'))
      end
    end

    context 'with a 2FA login code' do
      let(:params) { { 'email' => 'jane@example.com', 'password' => 'Secret123!', 'verification_code' => 'Ab3dE9fG' } }

      it 'masks the code' do
        expect(filtered['verification_code']).to eq('[FILTERED]')
      end
    end

    context 'with a Twilio inbound SMS' do
      let(:params) do
        { 'From' => '+13135550100', 'FromCity' => 'DETROIT', 'FromState' => 'MI', 'FromZip' => '48202', 'FromCountry' => 'US',
          'To' => '+15555550100', 'Body' => 'yes', 'MessageSid' => 'SM123' }
      end

      it 'masks the sender, the recipient number and the message' do
        expect(filtered.slice('From', 'FromCity', 'FromState', 'FromZip', 'FromCountry', 'To', 'Body').values).to all(eq('[FILTERED]'))
      end

      it 'keeps the message id' do
        expect(filtered.slice('MessageSid')).to eq('MessageSid' => 'SM123')
      end
    end

    context 'with snake_case params that only contain "from"' do
      let(:params) { { 'from' => '2026-01-01', 'date_from' => '2026-01-01' } }

      it 'keeps them' do
        expect(filtered).to eq(params)
      end
    end
  end

  # The second layer, for error events. Its filter is built when config/initializers/sentry.rb runs, so it only
  # sees keys added by initializers that load before it (filter_parameter_logging.rb does).
  describe '.configuration.before_send' do
    subject(:sent) { described_class.configuration.before_send.call(event, {}) }

    let(:params) do
      {
        'hfhs_patient_data' => { 'dob' => '2015-04-02', 'sex' => 'F', 'zip_code' => '48202', 'mrn' => '12345678', 'phone_type' => 'mobile' },
        'verification_code' => 'Ab3dE9fG',
        'From' => '+13135550100',
        'session_id' => 'f3b1c2d4'
      }
    end
    let(:masked_params) do
      {
        'hfhs_patient_data' => params['hfhs_patient_data'].transform_values { '[FILTERED]' },
        'verification_code' => '[FILTERED]',
        'From' => '[FILTERED]',
        'session_id' => 'f3b1c2d4'
      }
    end
    let(:event) do
      Sentry::Event.new(configuration: described_class.configuration).tap do |event|
        event.extra = { params: params }
        event.breadcrumbs = Sentry::BreadcrumbBuffer.new.tap do |buffer|
          buffer.record(Sentry::Breadcrumb.new(category: 'process_action.action_controller', data: { params: params }))
        end
      end
    end

    it 'masks patient fields, 2FA codes and the SMS sender in extra data' do
      expect(sent[:extra][:params]).to eq(masked_params)
    end

    it 'masks them in breadcrumbs' do
      expect(sent[:breadcrumbs][:values].first[:data]['params']).to eq(masked_params)
    end
  end
end
