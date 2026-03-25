# frozen_string_literal: true

module RequestProcessingErrors
  class RetryableError < StandardError; end
  class NonRetryableError < StandardError; end
end
