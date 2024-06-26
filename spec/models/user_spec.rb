# frozen_string_literal: true

require 'rails_helper'

describe User, type: :model do
  it { should have_many(:team_invitations).dependent(:destroy) }
  it { should have_many(:organization_invitations).dependent(:destroy) }
  it { should have_many(:health_system_invitations).dependent(:destroy) }
  it { should have_many(:health_clinic_invitations).dependent(:destroy) }
  it { should have_many(:chart_statistics).dependent(:nullify) }
  it { should have_many(:user_verification_codes).dependent(:destroy) }
  it { should have_many(:user_health_clinics) }
  it { should have_many(:admins_teams).dependent(:nullify) }
  it { should have_many(:user_log_requests).dependent(:destroy) }
  it { should have_many(:sessions).dependent(:restrict_with_exception) }
  it { should have_many(:user_sessions).dependent(:restrict_with_exception) }
  it { should have_many(:interventions).dependent(:restrict_with_exception) }
  it { should have_one(:phone).dependent(:destroy) }
  it { should have_one_attached(:avatar) }
  it { should have_many(:generated_reports_third_party_users).dependent(:destroy) }
  it { should have_many(:notifications).dependent(:destroy) }
  it { should have_many(:collaborations).dependent(:destroy) }

  it { should belong_to(:team).optional(true) }
  it { should belong_to(:organizable).optional(true) }

  describe 'participant' do
    subject { create(:user, :confirmed, :participant) }

    it { should be_valid }
    it { should have_many(:interventions) }
  end

  describe 'admin' do
    subject { create(:user, :confirmed, :admin) }

    it { should be_valid }
    it { should have_many(:interventions) }
  end

  describe 'team_is_present?' do
    context 'user has role team admin' do
      context 'team admin has not assigned team' do
        let(:user) { build_stubbed(:user, :team_admin, team_id: nil) }

        it 'is not valid' do
          expect(user).not_to be_valid
          expect(user.errors.messages[:roles]).to include(/Team Admin must have a team/)
        end
      end

      context 'team admin has assigned team' do
        let(:user) { build(:user, :team_admin) }

        it 'is valid' do
          expect(user).to be_valid
        end
      end
    end
  end

  describe 'organization_is_present?' do
    context 'user has role organization admin' do
      context 'organization admin has not assigned organization' do
        let(:user) { build_stubbed(:user, :organization_admin) }

        it 'is not valid' do
          expect(user).to be_valid
          expect(user.organizable).to be_nil
        end
      end

      context 'organization admin has assigned organization' do
        let(:user) { build(:user, :organization_admin, :with_organization) }

        it 'is valid' do
          expect(user).to be_valid
          expect(user.organizable).not_to be_nil
        end
      end
    end
  end

  describe '#time_zone' do
    %w[America/New_York Europe/Warsaw Europe/Vienna America/Chicago America/Denver
       America/Detroit].each do |time_zone|
      context "time zone is #{time_zone}" do
        let(:user) { build_stubbed(:user, :confirmed, :researcher, time_zone: time_zone) }

        it 'user is valid with time zone' do
          expect(user).to be_valid
        end
      end
    end
  end

  describe 'invalidate_token_after_changes' do
    let!(:user) { create(:user, :confirmed, :team_admin) }
    let!(:set_tokens) { user.create_new_auth_token }

    context 'roles changed' do
      it 'removes current user tokens' do
        expect { user.update(roles: ['researcher']) }.to change { user.reload.tokens }
                                                           .from(user.tokens).to({})
      end
    end

    context 'roles have not changed' do
      it 'does not remove user tokens' do
        expect { user.update(roles: %w[researcher team_admin]) }.not_to change { user.reload.tokens }
      end
    end

    context 'active changed to inactive' do
      it 'removes current user tokens' do
        expect { user.update(active: false) }.to change { user.reload.tokens }
                                                   .from(user.tokens).to({})
      end
    end

    context 'active changed to active' do
      before do
        user.update(active: false)
        user.update(tokens: user.tokens)
      end

      it 'does not remove user tokens' do
        expect { user.update(active: true) }.not_to change { user.reload.tokens }
      end
    end

    context 'active have not changed' do
      it 'does not remove user tokens' do
        expect { user.update(active: true) }.not_to change { user.reload.tokens }
      end
    end
  end

  context 'user has role health_system_admin' do
    let(:user) { build_stubbed(:user, :health_system_admin) }

    context 'user belongs to health system' do
      include_examples 'with health system'
    end

    context 'user doesn\'t belong to health system' do
      include_examples 'without health system'
    end
  end

  context 'user has role health_clinic_admin' do
    let(:user) { build_stubbed(:user, :health_clinic_admin) }

    context 'user belongs to health clinic' do
      include_examples 'with health clinic'
    end

    context 'user doesn\'t belong to health clinic' do
      include_examples 'without health clinic'
    end
  end

  context 'user has role researcher' do
    let(:user) { build_stubbed(:user, :researcher) }

    include_examples 'without team admin validations'
  end

  context 'user has role guest' do
    let(:user) { build_stubbed(:user, :guest) }

    include_examples 'without team admin validations'

    context 'after create don\'t send a welcome email' do
      it {
        expect do
          described_class.new.tap do |u|
            u.roles = %w[guest]
            u.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@guest.true"
            u.skip_confirmation!
            u.save(validate: false)
          end
        end.not_to change { ActionMailer::Base.deliveries.size }
      }
    end
  end

  context 'user has role review session' do
    it 'after create don\'t send a welcome email' do
      expect do
        described_class.new.tap do |u|
          u.roles = %w[guest]
          u.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@preview.session"
          u.skip_confirmation!
          u.save(validate: false)
        end
      end.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  context 'user has role admin' do
    let(:user) { build_stubbed(:user, :admin) }

    include_examples 'without team admin validations'
  end

  context 'user has role participant' do
    let(:user) { build_stubbed(:user, :participant) }

    include_examples 'without team admin validations'
  end

  describe 'navigator' do
    subject { create(:user, :confirmed, :navigator) }

    it { should be_valid }
  end

  describe 'sends welcoming email for participants after confirming the account' do
    let(:user) { create(:user, :participant, confirmed_at: nil) }

    before { ActiveJob::Base.queue_adapter = :test }

    it do
      expect { user.confirm }.to have_enqueued_job(ActionMailer::MailDeliveryJob).once
    end
  end

  context 'predefined participant' do
    it 'doesn\'t receive welcome emails' do
      expect do
        described_class.create!(first_name: 'Predefined', last_name: 'User', email: 'predefined_user@example.com', password: 'Password1!',
                                roles: ['predefined_participant'], terms: true, confirmed_at: DateTime.now)
      end.not_to change {
                   ActionMailer::Base.deliveries.size
                 }
    end
  end
end
