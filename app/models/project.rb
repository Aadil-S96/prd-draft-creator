class Project < ApplicationRecord
  belongs_to :user, optional: true

  enum :problem_type, {
    conversion_drop: 0,
    tech_issue: 1,
    supply_constraint: 2,
    growth_opportunity: 3,
    other: 4
  }
  
  enum :priority, { P0: 0, P1: 1, P2: 2 }
  
  enum :status, { draft: 0, in_progress: 1, shipped: 2 }
  
  validates :name, presence: true
  validates :problem_type, presence: true
  validates :priority, presence: true
  validates :status, presence: true
  validates :slack_thread_url, format: { with: URI::DEFAULT_PARSER.make_regexp, message: "must be a valid URL" }, allow_nil: true
  validates :notion_url, format: { with: URI::DEFAULT_PARSER.make_regexp, message: "must be a valid URL" }, allow_nil: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_priority, -> { order(priority: :asc) }
  scope :by_status, ->(status) { where(status: status) }
end

