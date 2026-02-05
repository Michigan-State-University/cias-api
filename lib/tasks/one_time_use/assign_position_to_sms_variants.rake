# frozen_string_literal: true

namespace :one_time_use do
  desc 'Assign correct position to existing sms plan variants'
  task assign_position_to_sms_variants: :environment do
    AuxiliarySmsPlan.find_each do |plan|
      plan.variants.find_each.with_index do |variant, index|
        variant.update!(position: index)
      end
    end
  end

  class AuxiliarySmsPlan < ActiveRecord::Base
    self.table_name = 'sms_plans'

    has_many :variants, class_name: 'AuxiliarySmsVariant', foreign_key: 'sms_plan_id'
  end

  class AuxiliarySmsVariant < ActiveRecord::Base
    self.table_name = 'sms_variants'

    belongs_to :sms_plan, class_name: 'AuxiliarySmsPlan', foreign_key: 'sms_plan_id'
  end
end
