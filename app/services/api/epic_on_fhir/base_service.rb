# frozen_string_literal: true

class Api::EpicOnFhir::BaseService
  protected

  def authentication
    @authentication ||= Api::EpicOnFhir::Authentication.call
  end

  def check_status(response)
    raise EpicOnFhir::UnexpectedError, I18n.t('epic_on_fhir.error.unexpected_error') if response.status != 200
  end
end
