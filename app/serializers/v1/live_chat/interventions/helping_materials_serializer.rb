# frozen_string_literal: true

class V1::LiveChat::Interventions::HelpingMaterialsSerializer < V1Serializer
  include FileHelper
  attributes :id

  has_many :navigator_links, serializer: V1::LiveChat::Interventions::LinkSerializer

  attribute :navigator_files do |object|
    (object.navigator_files || []).map do |file_data|
      map_file_data(file_data)
    end
  end

  attribute :filled_script_template do |object|
    map_file_data(object.filled_script_template) if object.filled_script_template.attached?
  end
end
