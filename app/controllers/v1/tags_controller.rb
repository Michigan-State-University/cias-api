# frozen_string_literal: true

class V1::TagsController < V1Controller
  def index
    tags = Tag.not_assigned_to_intervention(intervention_id).filter_by_name(search_param)
    paginated_collection = V1::Paginate.call(tags, start_index, end_index)
    render json: serialized_hash(paginated_collection).merge({ tags_size: tags.size }).to_json, status: :ok
  end

  private

  def search_param
    params.permit(:search)[:search]
  end

  def start_index
    params.permit(:start_index)[:start_index]&.to_i
  end

  def end_index
    params.permit(:end_index)[:end_index]&.to_i
  end

  def intervention_id
    params.permit(:intervention_id)[:intervention_id]
  end
end
