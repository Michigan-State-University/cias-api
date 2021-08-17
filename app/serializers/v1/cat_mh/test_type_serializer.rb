# frozen_string_literal: true

class V1::CatMh::TestTypeSerializer < V1Serializer
  attributes :id, :short_name, :name
  has_many :cat_mh_languages, through: :cat_mh_test_type_languages, serializer: V1::CatMh::LanguageSerializer
  has_many :cat_mh_time_frames, through: :cat_mh_test_type_time_frames, serializer: V1::CatMh::TimeFrameSerializer
  belongs_to :cat_mh_population, serializer: V1::CatMh::PopulationSerializer
end
