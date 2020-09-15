# frozen_string_literal: true

class User < ApplicationRecord
  devise :confirmable,
         :database_authenticatable,
         :pwned_password,
         :recoverable,
         :registerable,
         :rememberable,
         :timeoutable,
         :trackable,
         :validatable

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
  has_many :user_problems, dependent: :restrict_with_exception, inverse_of: :user
  has_many :answers, dependent: :restrict_with_exception, inverse_of: :user
  has_many :user_logs_requests, dependent: :restrict_with_exception
  has_one :address, dependent: :destroy, inverse_of: :user

  accepts_nested_attributes_for :address

  attribute :time_zone, :string, default: ENV.fetch('USER_DEFAULT_TIME_ZONE', 'America/New_York')

  scope :limit_to_roles, ->(roles) { where('ARRAY[?]::varchar[] && roles', roles) }

  def self.detailed_search(params)
    scope = all
    scope = scope.limit_to_roles(params[:roles]) if params[:roles].present?
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

  def destroy
    update(deactivated: true) unless deactivated
  end

  def active_for_authentication?
    super && !deactivated
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
