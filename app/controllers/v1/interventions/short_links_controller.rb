# frozen_string_literal: true

class V1::Interventions::ShortLinksController < V1Controller
  skip_before_action :authenticate_user!, only: %i[verify]

  def create
    authorize! :update, Intervention
    authorize! :update, intervention_load

    V1::ShortLinks::ManagerService.call(intervention_load, short_links_params)

    render json: serialized_short_links_with_clinics
  end

  def index
    authorize! :index, Intervention
    authorize! :index, intervention_load

    render json: serialized_short_links_with_clinics
  end

  def verify
    render json: V1::ShortLinks::MapService.call(name, current_v1_user)
    # render json: V1::ShortLinks::MapService.call(slug)
  end

  private

  def intervention_load
    @intervention_load ||= Intervention.accessible_by(current_ability).find(params[:intervention_id])
  end

  def short_links_params
    params.permit(short_links: %i[name health_clinic_id])[:short_links]
  end

  def short_links_collection
    intervention_load.reload.short_links
  end

  def health_clinics
    intervention_load.organization.health_clinics.active
  end

  def serialized_health_clinics
    if in_organization?
      {
        health_clinics: serialized_hash(health_clinics, 'SimpleHealthClinic')[:data]
      }
    else
      { health_clinics: nil }
    end
  end

  def serialized_short_links_with_clinics
    serialized_hash(short_links_collection).merge(serialized_health_clinics)
  end

  def in_organization?
    intervention_load.organization.present?
  end

  def name
    params[:name]
  end

  def name
    params[:name]
  end
end
