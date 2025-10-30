# frozen_string_literal: true

class RemoveV2RecordFieldFromChartStatistics < ActiveRecord::Migration[7.2]
  def change
    remove_legacy_records
    remove_column :chart_statistics, :v2_record
  end

  class AuxiliaryChartStatistic < ApplicationRecord
    self.table_name = 'chart_statistics'
  end

  private

  def remove_legacy_records
    if AuxiliaryChartStatistic.where(v2_record: true).any?
      AuxiliaryChartStatistic.where(v2_record: false, user_session_id: nil).delete_all
    end
  end
end
