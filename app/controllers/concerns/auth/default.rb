# frozen_string_literal: true

module Auth::Default
  protected

  def render_error(status, message, _data = nil)
    render json: { message: message }, status: status
  end

  def render_create_error(_errors = nil)
    render_error(422, resource_errors[:full_messages].first)
  end

  def render_create_success
    render json: V1::UserSerializer.new(@resource), status: :created
  end

  def render_destroy_success
    head :ok
  end

  def render_update_error
    render_error(422, resource_errors[:full_messages].first)
  end

  def render_update_success
    render json: serialized_response(@resource, 'User')
  end
end
