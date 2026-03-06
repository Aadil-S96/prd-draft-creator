class User < ApplicationRecord
  has_secure_password
  has_many :projects, dependent: :nullify

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password_digest_changed? }

  scope :recent, -> { order(created_at: :desc) }

  def display_name
    name.presence || email.split("@").first
  end

  def has_notion_config?
    notion_api_key.present? && notion_database_id.present?
  end
end
