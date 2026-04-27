# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::ParticipantAttributesValidator
  def self.call(participant_params_list)
    new(participant_params_list).call
  end

  def initialize(participant_params_list)
    @participant_params_list = participant_params_list
    @errors = []
    @seen_emails = Set.new
  end

  def call
    @participant_params_list.each_with_index { |params, idx| validate_participant(idx, params) }

    return if @errors.empty?

    raise ComplexException.new(
      I18n.t('predefined_participants.bulk_import.participant_validation_error'),
      { errors: @errors },
      :unprocessable_entity
    )
  end

  private

  def validate_participant(idx, params)
    check_intra_csv_duplicate_email(idx, params)

    user = V1::Intervention::PredefinedParticipants::CreateService.build_predefined_user(params)
    map_model_errors_to_hashes(user, idx, field_prefix: nil)

    validate_phone(idx, params, user) if params[:phone_attributes].present?
    validate_health_clinic(idx, params) if params[:health_clinic_id].present?
  end

  def check_intra_csv_duplicate_email(idx, params)
    return if params[:email].blank?

    if @seen_emails.include?(params[:email])
      add_error(idx, field: 'email', code: 'duplicate_in_csv')
    else
      @seen_emails << params[:email]
    end
  end

  def validate_phone(idx, params, user)
    phone_attrs = params[:phone_attributes].to_h.symbolize_keys.merge(user: user)
    phone = Phone.new(phone_attrs)
    map_model_errors_to_hashes(phone, idx, field_prefix: 'phone')
  end

  def validate_health_clinic(idx, params)
    return if HealthClinic.exists?(id: params[:health_clinic_id])

    add_error(idx, field: 'health_clinic_id', code: 'not_found')
  end

  def map_model_errors_to_hashes(record, idx, field_prefix:)
    return if record.valid?

    record.errors.details.each do |attr, detail_entries|
      field = field_prefix ? "#{field_prefix}.#{attr}" : attr.to_s
      detail_entries.each do |detail|
        add_error(idx, field: field, code: detail[:error].to_s)
      end
    end
  end

  def add_error(idx, field:, code:, **context)
    @errors << { row: idx, field: field, code: code, **context }
  end
end
