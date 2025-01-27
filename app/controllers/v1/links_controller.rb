# frozen_string_literal: true

class V1::LinksController < V1Controller
  skip_before_action :authenticate_user!

  def show
    link = Link.find_by!(slug: params[:slug])
    redirect_to link.url, allow_other_host: true
  end
end
