# frozen_string_literal: true

class V1::AudioController < V1Controller
  def create
    text = audio_params[:text]
    audio_url = V1::AudioService.new(text, preview: true).execute.url

    render json: { url: audio_url }
  end

  private

  def audio_params
    params.require(:audio).permit(:text)
  end
end
