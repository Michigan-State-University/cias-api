# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SMS campaigns routing', type: :routing do
  let(:intervention_id) { '3f0e1d62-5c1a-4a53-9a43-1b5a7a2c9d11' }
  let(:base) { "/v1/interventions/#{intervention_id}/predefined_participants" }
  let(:controller_name) { 'v1/interventions/predefined_participants/sms_campaigns' }

  it 'routes GET .../predefined_participants/sms_campaigns to sms_campaigns#index and not to predefined_participants#show' do
    expect(get: "#{base}/sms_campaigns").to route_to(controller: controller_name, action: 'index', intervention_id: intervention_id)
  end

  it 'routes POST .../predefined_participants/sms_campaigns to sms_campaigns#create' do
    expect(post: "#{base}/sms_campaigns").to route_to(controller: controller_name, action: 'create', intervention_id: intervention_id)
  end

  it 'routes GET .../predefined_participants/sms_campaigns/meta to sms_campaigns#meta' do
    expect(get: "#{base}/sms_campaigns/meta").to route_to(controller: controller_name, action: 'meta', intervention_id: intervention_id)
  end

  it 'control (green before implementation): GET .../predefined_participants/:id still routes to predefined_participants#show' do
    participant_id = '8a1b2c3d-0000-4000-8000-000000000001'
    expect(get: "#{base}/#{participant_id}").to route_to(controller: 'v1/interventions/predefined_participants', action: 'show',
                                                         intervention_id: intervention_id, id: participant_id)
  end

  it 'control (green before implementation): POST .../predefined_participants/bulk_create keeps its collection route' do
    expect(post: "#{base}/bulk_create").to route_to(controller: 'v1/interventions/predefined_participants', action: 'bulk_create',
                                                    intervention_id: intervention_id)
  end
end
