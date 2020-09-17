# frozen_string_literal: true

class Intervention::Schedule
  def initialize(source, next_inter = nil, next_user_inter = nil)
    @source = source
    @next_inter = next_inter
    @next_user_inter = next_user_inter
  end

  def days_after
    source.first.update!(schedule_at: next_inter)
    source.each_cons(2) do |int_crr, int_nxt|
      next unless int_nxt.schedule_days_after?
      next unless int_crr.schedule_at

      int_nxt.update!(schedule_at: int_crr.schedule_at + int_nxt.schedule_payload)
    end
  end

  def days_after_fill
    next_user_inter.update!(schedule_at: source.submitted_at.to_date + next_inter.schedule_payload)
  end

  private

  attr_accessor :source, :next_inter, :next_user_inter
end
