# frozen_string_literal: true

class ProcessRequestJob < ApplicationJob
  queue_as :default

  retry_on RequestProcessingErrors::RetryableError, attempts: ProcessingRequest::MAX_ATTEMPTS, wait: :exponentially_longer
  retry_on ActiveRecord::Deadlocked, attempts: 3, wait: :exponentially_longer

  def perform(request_id)
    request = ProcessingRequest.find(request_id)

    request.with_lock do
      return if request.terminal?
      return request.mark_cancelled! if request.cancelled?

      next_attempt = request.attempts + 1
      if next_attempt > ProcessingRequest::MAX_ATTEMPTS
        return request.mark_failed!(RequestProcessingErrors::RetryableError.new("max attempts exceeded"))
      end

      request.update!(attempts: next_attempt)
      request.mark_processing!
    end

    result = RequestProcessing::Processor.new(request).call

    request.with_lock do
      return request.mark_cancelled! if request.cancelled?
      request.mark_completed!(result)
    end
  rescue RequestProcessingErrors::RetryableError => e
    request&.with_lock do
      if request.attempts < ProcessingRequest::MAX_ATTEMPTS
        request.mark_retrying!(e)
      else
        request.mark_failed!(e)
      end
    end

    raise
  rescue RequestProcessingErrors::NonRetryableError => e
    request&.with_lock { request.mark_failed!(e) }
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn("ProcessingRequest #{request_id} missing - skipping job")
  end
end
