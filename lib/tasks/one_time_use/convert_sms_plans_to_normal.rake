
namespace :one_time_use do
  desc 'Converts all current SmsPlan instances to SmsPlan::Normal'
  task convert_current_sms_plans_to_normal: :environment do
    SmsPlan.where(type: 'SmsPlan').each do |plan|
      plan.update!(type: 'SmsPlan::Normal')
    end
  end
end
