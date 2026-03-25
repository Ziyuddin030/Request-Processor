# frozen_string_literal: true

module RequestProcessing
  class Processor
    def initialize(request)
      @request = request
    end

    def call
      ensure_not_cancelled!

      # Simulate real-world work. This can be replaced with an HTTP call or domain logic.
      simulate_latency

      ensure_not_cancelled!

      simulate_failures

      {
        message: "processed",
        processed_at: Time.current.iso8601,
        echo: request.payload
      }
    end

    private

    attr_reader :request

    def ensure_not_cancelled!
      request.reload
      raise RequestProcessingErrors::NonRetryableError, "request cancelled" if request.cancelled?
    end

    def simulate_latency
      delay = request.payload.dig("simulate", "delay_seconds")
      sleep(delay.to_f) if delay
    end

    def simulate_failures
      mode = request.payload.dig("simulate", "failure_mode")

      case mode
      when "retryable"
        raise RequestProcessingErrors::RetryableError, "simulated retryable failure"
      when "non_retryable"
        raise RequestProcessingErrors::NonRetryableError, "simulated non-retryable failure"
      when "flaky"
        # Fail the first N attempts, then succeed.
        fail_count = request.payload.dig("simulate", "failures_before_success").to_i
        raise RequestProcessingErrors::RetryableError, "simulated flaky failure" if request.attempts <= fail_count
      end
    end
  end
end
