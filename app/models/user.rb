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

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  validates :uid, :email, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :uid, uniqueness: { scope: :provider }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  has_many :problems, dependent: :restrict_with_exception
  has_many :answers, dependent: :restrict_with_exception
  has_many :user_logs_requests, dependent: :restrict_with_exception

  attribute :time_zone, :string, default: ENV.fetch('USER_DEFAULT_TIME_ZONE', 'Eastern Time (US & Canada)')

  scope :limit_to_roles, ->(roles) { where('ARRAY[?]::text[] && roles', roles) }

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
