class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :masqueradable, :database_authenticatable, :registerable, :validatable,
         :omniauthable,  omniauth_providers: %i[google_oauth2]

  has_one_attached :avatar
  has_person_name

  has_many :notifications, as: :recipient
  has_many :services, dependent: :destroy
end
