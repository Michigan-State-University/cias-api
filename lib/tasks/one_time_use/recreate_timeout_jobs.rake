# frozen_string_literal: true

namespace :one_time_use do
  task recreate_timeout_jobs: :environment do
    user_sessions_scope.find_each do |user_session|
      estimated_timeout_time = user_session.last_answer_at + user_session.session.autofinish_delay.minutes
      if estimated_timeout_time.future?
        recreate_timeout_job_for_user_session(user_session, estimated_timeout_time)
      elsif user_session.class == UserSession::Classic
        finish_due_classic_user_session(user_session, estimated_timeout_time)
      elsif user_session.class == UserSession::CatMh
        finish_due_catmh_user_session(user_session, estimated_timeout_time)
      end
    end
  end
end

private

def user_sessions_scope
  UserSession.joins(:session)
             .where(finished_at: nil)
             .where.not(last_answer_at: nil)
             .where('sessions.autofinish_enabled IS TRUE')
end

def recreate_timeout_job_for_user_session(user_session, timeout_datetime)
  job_exists = scheduled_set.each do |job|
    break true if job['args'].first >= {
      "job_class" => "UserSessionTimeoutJob",
      "arguments" => [user_session.id]
    }
  end || false

  UserSessionTimeoutJob.set(wait_until: timeout_datetime).perform_later(user_session.id) unless job_exists
end

def finish_due_classic_user_session(user_session, timeout_datetime)
  user_session.update(finished_at: timeout_datetime)
  user_session.answers.where(draft: true, alternative_branch: true).destroy_all # user_session.delete_alternative_answers
  user_session.reload

  # user_session.decrement_audio_usage
  unless user_session.name_audio.nil?
    user_session.name_audio.decrement(:usage_counter)
    user_session.name_audio.save!
  end

  V1::ChartStatistics::CreateForUserSession.call(user_session)

  AfterFinishUserSessionJob.perform_later(user_session.id, user_session.session.intervention)

  user_session.update_user_intervention(session_is_finished: true)
end

def finish_due_catmh_user_session(user_session, timeout_datetime)
  user_session.update!(finished_at: timeout_datetime)

  cat_mh_api = Api::CatMh.new

  result = cat_mh_api.get_result(user_session)
  result_to_answers(user_session, result['body']) if result['status'] == 200
  cat_mh_api.terminate_intervention(user_session)

  GenerateUserSessionReportsJob.perform_later(user_session.id)

  V1::ChartStatistics::CreateForUserSession.call(user_session)

  user_session.update_user_intervention(session_is_finished: true)
end

def scheduled_set
  @scheduled_set ||= Sidekiq::ScheduledSet.new
end

def result_to_answers(user_session, result)
  available_test_types = user_session.session.cat_mh_test_types
  result['tests'].each do |test|
    test_type = available_test_types.find_by(short_name: test['type'].downcase)
    test_type.cat_mh_test_attributes.each do |variable|
      Answer::CatMh.create!(
        user_session_id: user_session.id,
        body: {
          'data' => [
            { 'var' => "#{test_type.short_name}_#{variable.name}", 'value' => test[variable.name] }
          ]
        }
      )
    end
  end
end
