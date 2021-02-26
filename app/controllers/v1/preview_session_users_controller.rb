# frozen_string_literal: true

class V1::PreviewSessionUsersController < V1Controller
  def create
    authorize! :create, :preview_session_user
    user = create_preview_session_user
    render json: user.create_new_auth_token
  end

  private

  def create_preview_session_user
    User.new.tap do |u|
      u.preview_session_id = session_id
      u.roles = %w[preview_session]
      u.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@preview.session"
      u.skip_confirmation!
      u.save(validate: false)
    end
  end

  def session_id
    params.require(:session_id)
  end
end
