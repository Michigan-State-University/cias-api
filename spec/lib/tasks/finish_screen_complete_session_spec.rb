# frozen_string_literal: true

RSpec.describe 'finish_screen:complete_session' do
  subject(:invoke) { Rake::Task['finish_screen:complete_session'].invoke }

  let(:intervention) { create(:flexible_order_intervention, status: 'published') }
  let!(:finish_screens) { Array.new(2) { create_finish_screen(intervention) } }
  let!(:other_finish_screen) { create_finish_screen(create(:flexible_order_intervention)) }
  let(:original_env) { ENV.fetch('INTERVENTION_IDS', nil) }

  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['finish_screen:complete_session'].reenable
    original_env
    ENV.delete('INTERVENTION_IDS')
    allow($stdout).to receive(:write)
  end

  after { original_env.nil? ? ENV.delete('INTERVENTION_IDS') : ENV['INTERVENTION_IDS'] = original_env }

  def create_finish_screen(intervention)
    session = create(:session, intervention: intervention)
    create(:question_finish, :with_dashboard_button, question_group: create(:question_group_finish, session: session))
  end

  def dashboard_buttons_of(questions)
    questions.map { |question| question.reload.settings['show_dashboard_button'] }
  end

  context 'with a module intervention id' do
    before { ENV['INTERVENTION_IDS'] = intervention.id }

    it 'turns the dashboard button off on every finish screen of the intervention' do
      invoke

      expect(dashboard_buttons_of(finish_screens)).to all(be(false))
    end

    it 'does not touch finish screens of other interventions' do
      invoke

      expect(dashboard_buttons_of([other_finish_screen])).to all(be(true))
    end
  end

  context 'without INTERVENTION_IDS' do
    it 'aborts' do
      expect { invoke }.to raise_error(SystemExit)
    end
  end

  context 'with an unknown intervention id' do
    before { ENV['INTERVENTION_IDS'] = "#{intervention.id},#{SecureRandom.uuid}" }

    it 'aborts without changing anything' do
      expect { invoke }.to raise_error(SystemExit)
      expect(dashboard_buttons_of(finish_screens)).to all(be(true))
    end
  end

  context 'with a sequential intervention id' do
    let(:sequential_finish_screen) { create_finish_screen(create(:intervention)) }

    before { ENV['INTERVENTION_IDS'] = sequential_finish_screen.question_group.session.intervention_id }

    it 'aborts without changing anything' do
      expect { invoke }.to raise_error(SystemExit)
      expect(dashboard_buttons_of([sequential_finish_screen])).to all(be(true))
    end
  end
end
