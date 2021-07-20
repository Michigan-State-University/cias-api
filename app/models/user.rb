# frozen_string_literal: true

class User < ApplicationRecord
  has_paper_trail skip: %i[
    first_name last_name email uid migrated_first_name migrated_last_name migrated_email migrated_uid
  ]
  before_save :invalidate_token_after_changes

  devise :confirmable,
         :database_authenticatable,
         :invitable,
         :recoverable,
         :registerable,
         :rememberable,
         :timeoutable,
         :trackable,
         :validatable

  extend DefaultValues
  include DeviseTokenAuth::Concerns::User
  include EnumerateForConcern

  # Order of roles is important because final authorization is the sum of all roles
  APP_ROLES = %w[guest preview_session participant third_party health_clinic_admin health_system_admin
                 organization_admin researcher e_intervention_admin team_admin admin].freeze

  TIME_ZONES = TZInfo::Timezone.all_identifiers.freeze

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  validates :time_zone, inclusion: { in: TIME_ZONES }
  validate :team_is_present?, if: :team_admin?, on: :update

  has_one :phone, dependent: :destroy
  accepts_nested_attributes_for :phone, update_only: true
  has_one_attached :avatar

  has_many :interventions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_sessions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :sessions, through: :user_sessions, dependent: :restrict_with_exception
  has_many :user_log_requests, dependent: :destroy
  belongs_to :team, optional: true
  belongs_to :organizable, polymorphic: true, optional: true
  has_many :user_health_clinics, dependent: :destroy
  has_many :admins_teams, class_name: 'Team', dependent: :nullify,
                          foreign_key: :team_admin_id, inverse_of: :team_admin

  has_many :team_invitations, dependent: :destroy
  has_many :organization_invitations, dependent: :destroy
  has_many :health_system_invitations, dependent: :destroy
  has_many :health_clinic_invitations, dependent: :destroy

  has_many :generated_reports_third_party_users, foreign_key: :third_party_id, inverse_of: :third_party,
                                                 dependent: :destroy
  has_many :user_verification_codes, dependent: :destroy
  has_many :chart_statistics, dependent: :nullify

  attribute :time_zone, :string, default: ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')
  attribute :roles, :string, array: true, default: assign_default_values('roles')

  delegate :name, to: :team, prefix: true, allow_nil: true

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :researchers, -> { limit_to_roles('researcher') }
  scope :third_parties, -> { limit_to_roles('third_party') }
  scope :from_team, ->(team_id) { where(team_id: team_id) }
  scope :team_admins, -> { limit_to_roles('team_admin') }
  scope :participants, -> { limit_to_roles('participant') }
  scope :limit_to_active, -> { where(active: true) }
  scope :limit_to_roles, ->(roles) { where('ARRAY[?]::varchar[] && roles', roles) if roles.present? }
  scope :name_contains, lambda { |substring|
    if substring.present?
      ids = select { |u| "#{u.first_name} #{u.last_name} #{u.email}" =~ /#{substring.downcase}/i }.map(&:id)
      User.where(id: ids)
    end
  }

  encrypts :email, :first_name, :last_name, :uid
  blind_index :email, :uid

  def self.detailed_search(params)
    scope = all
    scope = params[:user_roles].include?('researcher') ? users_for_researcher(params, scope) : scope.limit_to_roles(params[:roles])
    scope = params.key?(:active) ? scope.where(active: params[:active]) : scope.limit_to_active
    scope = scope.from_team(params[:team_id]) if params.key?(:team_id) && params[:user_roles].exclude?('researcher')
    scope = scope.name_contains(params[:name]) # rubocop:disable Style/RedundantAssignment
    scope
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

  def active_for_authentication?
    super && active
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def deactivated?
    !active?
  end

  def not_a_third_party?
    roles.exclude?('third_party')
  end

  def with_invalid_email?
    roles.include?('guest') || roles.include?('preview_session')
  end

  def accepted_health_clinic_ids
    return unless role?('health_clinic_admin')

    health_clinic_ids = health_clinic_invitations.where.not(accepted_at: nil).map(&:health_clinic_id)
    health_clinic_ids.append(organizable.id) if organizable
    health_clinic_ids
  end

  private

  def self.users_for_researcher(params, scope)
    if params[:roles]&.include?('researcher')
      scope.researchers.from_team(params[:team_id])
    else
      scope.participants
    end
  end

  def team_admin?
    roles.include?('team_admin')
  end

  def team_is_present?
    return if Team.exists?(team_admin_id: id)

    errors.add(:roles, :team_id_is_required_for_team_admin)
  end

  def invalidate_token_after_changes
    return unless persisted?
    return if !roles_changed? && (!active_changed? || active)

    self.tokens = {}
  end

  private_class_method :users_for_researcher
end
