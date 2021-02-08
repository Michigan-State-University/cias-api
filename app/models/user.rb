# frozen_string_literal: true

class User < ApplicationRecord
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
  APP_ROLES = %w[guest participant researcher team_admin admin].freeze

  TIME_ZONES = ActiveSupport::TimeZone::MAPPING.values.uniq.sort.freeze

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  validates :time_zone, inclusion: { in: TIME_ZONES }
  validate :team_is_present?, if: :team_admin?
  validate :team_admin_already_exists?, if: :team_admin?

  has_one :phone, dependent: :destroy
  accepts_nested_attributes_for :phone, update_only: true
  has_one_attached :avatar

  has_many :interventions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_sessions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :sessions, through: :user_sessions, dependent: :restrict_with_exception
  has_many :user_log_requests, dependent: :destroy
  belongs_to :team, optional: true
  has_many :team_invitations, dependent: :destroy

  attribute :time_zone, :string, default: ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')
  attribute :roles, :string, array: true, default: assign_default_values('roles')

  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :researchers, -> { limit_to_roles('researcher') }
  scope :from_team, ->(team_id) { where(team_id: team_id) }
  scope :team_admins, -> { limit_to_roles('team_admin') }
  scope :limit_to_active, -> { where(active: true) }
  scope :limit_to_roles, ->(roles) { where('ARRAY[?]::varchar[] && roles', roles) if roles.present? }
  scope :name_contains, lambda { |substring|
    where("CONCAT(first_name, ' ', last_name) ILIKE :substring OR email ILIKE :substring", substring: "%#{substring.downcase}%") if substring.present?
  }

  def self.detailed_search(params)
    scope = all
    scope = if params.key?(:active)
              scope.where(active: params[:active])
            else
              scope.limit_to_active
            end
    scope = scope.limit_to_roles(params[:roles])
    scope = scope.from_team(params[:team_id]) if params.key?(:team_id)
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

  def active_for_authentication?
    super && active
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  private

  def team_admin?
    roles.include?('team_admin')
  end

  def team_is_present?
    return if team_id.present?

    errors.add(:roles, :team_id_is_required_for_team_admin)
  end

  def team_admin_already_exists?
    return unless User.limit_to_roles(['team_admin']).
                       from_team(team_id).
                       where.not(id: id).exists?

    errors.add(:team_id, :team_admin_already_exists_for_the_team)
  end
end
