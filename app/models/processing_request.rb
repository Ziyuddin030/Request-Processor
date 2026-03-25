# frozen_string_literal: true

class ProcessingRequest < ApplicationRecord
  MAX_ATTEMPTS = 3

  enum :status, {
    pending: "pending",
    processing: "processing",
    retrying: "retrying",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled"
  }, validate: true

  validates :idempotency_key, presence: true
  validates :request_hash, presence: true
  validates :payload, presence: true
  validates :status, presence: true
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }

  after_commit :enqueue_processing_job, on: :create

  def cancelable?
    pending? || processing? || retrying?
  end

  def terminal?
    completed? || failed? || cancelled?
  end

  def mark_processing!
    update!(status: "processing", processing_started_at: Time.current)
  end

  def mark_retrying!(error)
    update!(
      status: "retrying",
      last_failed_at: Time.current,
      last_error_class: error.class.name,
      last_error_message: error.message
    )
  end

  def mark_failed!(error)
    update!(
      status: "failed",
      last_failed_at: Time.current,
      last_error_class: error.class.name,
      last_error_message: error.message
    )
  end

  def mark_completed!(result)
    update!(
      status: "completed",
      processed_at: Time.current,
      result: result,
      last_error_class: nil,
      last_error_message: nil
    )
  end

  def mark_cancelled!
    update!(status: "cancelled", cancelled_at: Time.current)
  end

  private

  def enqueue_processing_job
    ProcessRequestJob.perform_later(id)
  end
end
