# frozen_string_literal: true

require 'cancan/matchers'

describe User do
  describe 'abilities' do
    subject(:ability) { Ability.new(user) }

    context 'admin' do
      let(:user) { build_stubbed(:user, :confirmed, :admin) }

      it 'can create preview session users' do
        expect(subject).to have_abilities({ create: true }, :preview_session_user)
      end
    end

    context 'researcher' do
      let(:user) { build_stubbed(:user, :confirmed, :researcher) }

      it 'can create preview session users' do
        expect(subject).to have_abilities({ create: true }, :preview_session_user)
      end
    end

    context 'team admin' do
      let(:user) { build_stubbed(:user, :confirmed, :team_admin) }

      it 'can create preview session users' do
        expect(subject).to have_abilities({ create: true }, :preview_session_user)
      end
    end

    context 'guest' do
      let(:user) { build_stubbed(:user, :confirmed, :guest) }

      it 'can not create preview session users' do
        expect(subject).to have_abilities({ create: false }, :preview_session_user)
      end
    end

    context 'participant' do
      let(:user) { build_stubbed(:user, :confirmed, :participant) }

      it 'can not create preview session users' do
        expect(subject).to have_abilities({ create: false }, :preview_session_user)
      end
    end
  end
end
