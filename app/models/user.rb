# frozen_string_literal: true

class User < ApplicationRecord
  has_paper_trail skip: %i[
    first_name last_name email uid migrated_first_name migrated_last_name migrated_email migrated_uid
  ]

  devise :confirmable,
         :database_authenticatable,
         :invitable,
         :recoverable,
         :registerable,
         :rememberable,
         :timeoutable,
         :trackable,
         :validatable,
         :argon2,
         argon2_options: { migrate_from_devise_argon2_v1: true }

  extend DefaultValues
  include DeviseTokenAuth::Concerns::User
  include EnumerateForConcern

  # Order of roles is important because final authorization is the sum of all roles
  APP_ROLES = %w[guest preview_session participant third_party health_clinic_admin health_system_admin
                 organization_admin researcher e_intervention_admin team_admin admin navigator predefined_participant].freeze

  FORMATTING_APP_ROLE_EXCEPTIONS = {
    'e_intervention_admin' => 'E-intervention admin',
    'third_party' => 'third party user'
  }.freeze

  TIME_ZONES = TZInfo::Timezone.all_identifiers.freeze

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  # VALIDATIONS
  validates :time_zone, inclusion: { in: TIME_ZONES }
  validate :team_is_present?, if: :team_admin?, on: :update
  validates :terms, acceptance: { on: :create, accept: true }

  # PHONE NUMBER
  has_one :phone, dependent: :destroy
  accepts_nested_attributes_for :phone, update_only: true

  # ADDITIONAL PARAMETERS FOR PREDEFINED PARTICIPANTS
  has_one :predefined_user_parameter, dependent: :destroy
  delegate :full_number, to: :phone, allow_nil: true
  delegate :external_id, to: :predefined_user_parameter, allow_nil: true

  # AVATAR
  has_one_attached :avatar

  # INTERVENTIONS
  has_many :interventions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_interventions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_sessions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :sessions, through: :user_sessions, dependent: :restrict_with_exception
  has_many :user_log_requests, dependent: :destroy

  # TEAMS
  belongs_to :team, optional: true # for members of team
  has_many :admins_teams, class_name: 'Team', dependent: :nullify,
                          foreign_key: :team_admin_id, inverse_of: :team_admin # for team admin
  delegate :name, to: :team, prefix: true, allow_nil: true

  # ORGANIZATIONS
  belongs_to :organizable, polymorphic: true, optional: true # for members of organization/health system
  has_many :user_health_clinics, dependent: :destroy # for members of health clinics
  has_many :e_intervention_admin_organizations, dependent: :destroy
  has_many :organizations, through: :e_intervention_admin_organizations

  # INVITATIONS
  has_many :team_invitations, dependent: :destroy
  has_many :organization_invitations, dependent: :destroy
  has_many :health_system_invitations, dependent: :destroy
  has_many :health_clinic_invitations, dependent: :destroy

  # REPORTS AVAILABLE FOR THIRD PARTY USER
  has_many :generated_reports_third_party_users, foreign_key: :third_party_id, inverse_of: :third_party,
                                                 dependent: :destroy

  # DOWNLOADED REPORTS
  has_many :downloaded_reports, dependent: :destroy

  # CHARTS
  has_many :chart_statistics, dependent: :nullify # statistics of user answers

  # LIVE CHAT
  has_many :interlocutors, class_name: 'LiveChat::Interlocutor', dependent: :restrict_with_exception
  has_many :conversations, class_name: 'LiveChat::Conversation', through: :interlocutors
  has_many :live_chat_summoning_users, class_name: 'LiveChat::SummoningUser', dependent: :destroy

  # NOTIFICATIONS
  has_many :notifications, dependent: :destroy

  # USER IN GENERAL
  has_many :user_verification_codes, dependent: :destroy
  attribute :time_zone, :string, default: -> { ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York') }
  attribute :roles, :string, array: true, default: -> { assign_default_values('roles') }

  # HENRY FORDS
  belongs_to :hfhs_patient_detail, optional: true

  # COLLABORATIONS
  has_many :collaborations, class_name: 'Collaborator', dependent: :destroy

  # STARS
  has_many :stars, dependent: :destroy

  # SCOPES
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :researchers, -> { limit_to_roles('researcher') }
  scope :with_intervention_creation_access, -> { limit_to_roles(%w[e_intervention_admin researcher team_admin]) }
  scope :e_intervention_admins, -> { limit_to_roles('e_intervention_admin') }
  scope :third_parties, -> { limit_to_roles('third_party') }
  scope :from_team, ->(team_id) { team_id.present? ? left_joins(:organization_invitations).where(users: { team_id: team_id }) : User.none }
  scope :from_organization, ->(organization_id) { where(organizable_id: organization_id) }
  scope :team_admins, -> { limit_to_roles('team_admin') }
  scope :participants, -> { limit_to_roles('participant') }
  scope :limit_to_active, -> { where(active: true) }
  scope :limit_to_roles, ->(roles) { where('ARRAY[?]::varchar[] && roles', roles) if roles.present? }

  # rubocop:disable Layout/LineLength
  scope :active_users_invited_to_organizations, ->(organization_ids) { left_joins(:organization_invitations).where('organization_invitations.organization_id IN (?) AND organization_invitations.accepted_at IS NOT NULL', organization_ids) }
  scope :active_users_assigned_to_organizations, ->(organization_ids) { left_joins(:organization_invitations).where('users.organizable_id IN (?) AND users.confirmed_at IS NOT NULL', organization_ids) }
  scope :active_e_intervention_admins_from_organizations, ->(organization_ids) { organization_ids.present? ? active_users_invited_to_organizations(organization_ids).or(active_users_assigned_to_organizations(organization_ids)) : User.none }
  scope :from_team_or_organization, ->(team_id, organization_ids) { active_e_intervention_admins_from_organizations(organization_ids).or(from_team(team_id)) }
  # rubocop:enable Layout/LineLength

  scope :name_contains, lambda { |substring|
    if substring.present?
      ids = select { |u| "#{u.first_name} #{u.last_name} #{u.email}" =~ /#{substring.downcase}/i }.map(&:id)
      User.where(id: ids)
    end
  }

  validates :avatar, content_type: %w[image/png image/jpeg], size: { less_than: 10.megabytes }

  # BEFORE/AFTER ACTIONS
  before_save :invalidate_token_after_changes
  before_update :set_roles_to_uniq, if: :roles_changed?
  before_update :set_autogenerated_email, if: :email_bidx_changed?
  after_save :send_welcome_email, if: -> { saved_change_to_attribute?(:confirmed_at) && !confirmed_at.nil? }
  after_create_commit :set_terms_confirmed_date

  # ENCRYPTION
  has_encrypted :email, :first_name, :last_name, :uid
  blind_index :email, :uid

  # METHODS
  def self.detailed_search(params)
    user_roles = params[:user_roles]

    scope = all
    scope = if include_researcher_or_e_intervention_admin?(user_roles)
              users_for_researcher_or_e_intervention_admin(params, scope)
            else
              scope = users_for_team(params, scope) if params.key?(:team_id)
              scope.limit_to_roles(params[:roles])
            end

    scope = params.key?(:active) ? scope.where(active: params[:active]) : scope.limit_to_active
    scope.name_contains(params[:name])
  end

  def ability
    @ability ||= Ability.new(self)
  end

  def role?(name)
    roles.include?(name)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def deactivate!
    update!(active: false) if active
  end

  def activate!
    update!(active: true) unless active
  end

  def deactivated?
    !active?
  end

  def not_a_third_party?
    roles.exclude?('third_party')
  end

  def with_invalid_email?
    return email_autogenerated if roles.include?('predefined_participant')

    roles.intersect?(%w[guest preview_session])
  end

  def cache_key
    "user/#{id}-#{updated_at&.to_fs(:number)}"
  end

  def accepted_health_clinic_ids
    return unless role?('health_clinic_admin')

    health_clinic_ids = health_clinic_invitations.where.not(accepted_at: nil).map(&:health_clinic_id)
    health_clinic_ids.append(organizable.id) if organizable
    health_clinic_ids
  end

  def accepted_organization_ids
    return unless role?('e_intervention_admin')

    organization_ids = organization_invitations.where.not(accepted_at: nil).map(&:organization_id)
    organization_ids.append(organizable.id) if organizable
    organization_ids
  end

  def set_terms_confirmed_date
    self.terms_confirmed_at = Time.current
    save!
  end

  def set_roles_to_uniq
    self.roles = roles.uniq
  end

  def set_autogenerated_email
    self.email_autogenerated = false
  end

  def self.users_for_researcher_or_e_intervention_admin(params, scope)
    if params[:roles]&.include?('researcher') && params[:roles].include?('e_intervention_admin')
      scope.with_intervention_creation_access.from_team(params[:team_id])
    elsif params[:roles]&.include?('researcher')
      scope.researchers.from_team(params[:team_id])
    elsif params[:roles]&.include?('e_intervention_admin')
      scope.e_intervention_admins.from_team(params[:team_id])
    else
      scope.participants
    end
  end

  def self.include_researcher_or_e_intervention_admin?(user_roles)
    (user_roles.include?('researcher') && user_roles.size == 1) || user_roles.include?('e_intervention_admin')
  end

  def active_for_authentication?
    super && active
  end

  def accepted_organization
    organization_ids = organization_invitations.where.not(accepted_at: nil).map(&:organization_id)

    Organization.where(id: organizable_id).or(Organization.where(id: organization_ids))
  end

  APP_ROLES.each do |role|
    define_method :"#{role}?" do
      roles.include?(role)
    end
  end

  def human_readable_role
    FORMATTING_APP_ROLE_EXCEPTIONS[roles.first] || roles.first.tr('_', ' ')
  end

  def missing_require_fields?
    first_name.blank? || last_name.blank? || !terms
  end

  def self.invite!(attributes = {}, invited_by = nil, options = {}, &block)
    user = User.new(**attributes)
    return user if user.tap(&:valid?).errors.messages_for(:email).include? 'is not an email'

    super
  end

  private

  def send_welcome_email
    return if role?('guest') || role?('preview_session') || role?('predefined_participant')

    mailer = role?('participant') && user_interventions.present? ? UserMailer.with(locale: user_interventions.first.intervention.language_code) : UserMailer
    mailer.welcome_email(human_readable_role, email).deliver_later
  end

  def team_is_present?
    return false if Team.exists?(team_admin_id: id)

    errors.add(:roles, :team_admin_must_have_a_team)
  end

  def invalidate_token_after_changes
    return unless persisted?
    return if !roles_changed? && (!active_changed? || active)

    self.tokens = {}
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  class << self
    private

    def users_for_researcher(params, scope)
      if params[:roles]&.include?('researcher')
        scope.researchers.from_team(params[:team_id])
      else
        scope.participants
      end
    end

    def participants_with_answers_ids(user)
      result = Session.where(intervention_id: user.interventions.select(:id)).pluck(:id)
      return User.none if result.blank?

      User.participants.select { |participant| Answer.user_answers(participant.id, result).any? }.pluck(:id)
    end

    def participants_with_answers(scope)
      User.participants.where(id: scope.with_intervention_creation_access.flat_map { |user| participants_with_answers_ids(user) })
    end

    def users_for_team(params, scope)
      scope = scope.from_team(params[:team_id])
      scope.or(participants_with_answers(scope.or(User.where(id: params[:user_id])))) # participants of researchers and e_intervention admins of team
    end
  end
end
