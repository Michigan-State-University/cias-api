# frozen_string_literal: true

RSpec.describe 'POST /v1/sms/replay', type: :request do
  let(:params) do
    {
      body: 'EXAMPLE',
      from: '+48555777555',
      to: '+48555777888'
    }
  end
  let(:request) { post v1_sms_replay_path, params: params }

  it 'receive and pass params to service' do
    expect(V1::Sms::Replay).to receive(:call).with(
      params[:from], params[:to], params[:body]
    )
    request
  end

  it 'correct type of response' do
    request
    expect(response.headers['Content-Type']).to eq('application/xml; charset=utf-8')
  end
end
