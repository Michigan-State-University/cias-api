# frozen_string_literal: true

class LiveChat::Interventions::NavigatorSetup < ApplicationRecord
  self.table_name = 'live_chat_navigator_setups'

  belongs_to :intervention, class_name: 'Intervention', dependent: :destroy
  has_many :participant_links, lambda {
                                 where link_for: 'participants'
                               }, class_name: 'LiveChat::Interventions::Link', inverse_of: :navigator_setup, dependent: :destroy
  has_many :navigator_links, -> { where link_for: 'navigators' }, class_name: 'LiveChat::Interventions::Link', inverse_of: :navigator_setup, dependent: :destroy
  has_one :phone, dependent: :nullify

  has_many_attached :participant_files, dependent: :purge_later
  has_many_attached :navigator_files, dependent: :purge_later
  has_one_attached :filled_script_template, dependent: :purge_later

  validates :filled_script_template, content_type: %w[text/csv], size: { less_than: 5.megabytes }
end
