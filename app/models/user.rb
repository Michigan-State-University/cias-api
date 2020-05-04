# frozen_string_literal: true

class User < ApplicationRecord
  include DeviseTokenAuth::Concerns::User
  include EnumerateForConcern

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable,
         :registerable,
         :rememberable,
         :trackable,
         :validatable

  APP_ROLES = %w[administrator content_administrator group_coder participant research_assistant].freeze

  enumerate_for :roles,
                APP_ROLES,
                multiple: true,
                allow_blank: true

  validates :email, presence: true
  validates :email, uniqueness: true

  def ability
    @ability ||= Ability.new(self)
  end

  def role?(name)
    roles.include?(name)
  end

  def to_s
    "#{first_name} #{last_name}"
  end
end
