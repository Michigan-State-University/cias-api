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
  APP_ROLES = %w[guest participant researcher admin].freeze

  TIME_ZONES = ActiveSupport::TimeZone::MAPPING.values.uniq.sort.freeze

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  validates :phone, phone: true, allow_blank: true
  validates :time_zone, inclusion: { in: TIME_ZONES }

  has_one_attached :avatar

  has_many :problems, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_sessions, dependent: :restrict_with_exception, inverse_of: :user
  has_many :sessions, through: :user_sessions, dependent: :restrict_with_exception
  has_many :answers, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_log_requests, dependent: :destroy

  attribute :time_zone, :string, default: ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')
  attribute :roles, :string, array: true, default: assign_default_values('roles')

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
end
