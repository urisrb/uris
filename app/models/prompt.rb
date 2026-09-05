class Prompt < ApplicationRecord
  include TenantScoped

  MAX_REQUEST = 100_000

  belongs_to :resource
  belongs_to :promptable, polymorphic: true, optional: true

  validates :role, presence: true
  validates :model, presence: true
  validates :request, presence: true

  scope :finished, -> { where.not(finished_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def self.open!(resource:, role:, model:, request:, promptable: nil, attempt: 1)
    create!(
      resource: resource,
      promptable: promptable,
      role: role.to_s,
      model: model,
      attempt: attempt,
      request: request.to_s.truncate(MAX_REQUEST),
      started_at: Time.current
    )
  end

  def finish!(content)
    update!(response: { "content" => content.to_s }, finished_at: Time.current)
  end

  def fail!(error)
    update!(
      response: { "error" => { "class" => error.class.name, "message" => error.message.truncate(500) } },
      finished_at: Time.current
    )
  end

  def content = response["content"]

  def error = response["error"]

  def failed? = response.key?("error")

  def duration_ms
    return nil if started_at.nil? || finished_at.nil?

    ((finished_at - started_at) * 1000).round
  end
end
