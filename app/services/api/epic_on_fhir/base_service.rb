# frozen_string_literal: true

class Api::EpicOnFhir::BaseService
  def call
    response = request

    check_status(response)

    parsed_response = JSON.parse(response.body).deep_symbolize_keys

    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.patient.not_found') if not_found_condition?(parsed_response)

    parsed_response
  rescue EpicOnFhir::UnexpectedError => e
    send_error_to_sentry(e, response)
    raise
  end

  protected

  def authentication
    @authentication ||= Api::EpicOnFhir::Authentication.call
  end

  def check_status(response)
    raise EpicOnFhir::UnexpectedError, I18n.t('epic_on_fhir.error.unexpected_error') if response.status != 200
  end

  def request
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  def not_found_condition?(_response)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  private

  def send_error_to_sentry(error, response)
    Sentry.capture_exception(error) do |scope|
      scope.set_context(
        'epic_on_fhir_request',
        {
          endpoint: self.class::ENDPOINT
        }
      )
      scope.set_context(
        'epic_on_fhir_response',
        {
          anonymized_body: parse_response_body(response),
          status: response&.status
        }
      )
    end
  end

  def parse_response_body(response)
    return nil unless response&.body

    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end
end
