# frozen_string_literal: true

class V1::CatMh::TestTypesController < V1Controller
  def index
    authorize! :read_cat_resources, current_v1_user

    render json: test_types_response(CatMhTestType.all)
  end

  def available_tests
    authorize! :read_cat_resources, current_v1_user

    tests = CatMhTestType.joins(:cat_mh_test_type_languages, :cat_mh_test_type_time_frames).where(cat_mh_population_id: population_id).
      where(cat_mh_test_type_languages: { cat_mh_language_id: language_id })
    tests = tests.where(cat_mh_test_type_time_frames: { cat_mh_time_frame_id: time_frame_id }) if time_frame_id

    render json: test_types_response(tests)
  end

  private

  def test_types_response(tests)
    V1::CatMh::TestTypeSerializer.new(tests).serializable_hash.to_json
  end

  def language_id
    params.require(:language_id).to_i
  end

  def time_frame_id
    params.permit(:time_frame_id)[:time_frame_id]
  end

  def population_id
    params.require(:population_id).to_i
  end
end
