# frozen_string_literal: true

class User < ApplicationRecord
  devise :confirmable,
         :database_authenticatable,
         :recoverable,
         :registerable,
         :rememberable,
         :trackable,
         :validatable

  include DeviseTokenAuth::Concerns::User
  include EnumerateForConcern

  # Order of roles is important because final authorization is the sum of all roles
  APP_ROLES = %w[participant group_coder research_assistant content_administrator administrator].freeze

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  validates :email, presence: true
  validates :email, uniqueness: true

  has_many :interventions, dependent: :restrict_with_exception

  def ability
    @ability ||= Ability.new(self)
  end

  def role?(name)
    roles.include?(name)
  end

  def to_s
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
