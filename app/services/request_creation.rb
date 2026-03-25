# frozen_string_literal: true

class RequestCreation
  Result = Struct.new(:request, :created, :conflict, :error_message, keyword_init: true)

  def initialize(idempotency_key:, payload_param:)
    @idempotency_key = idempotency_key.to_s.strip
    @payload_param = payload_param
  end

  def call
    return error("Idempotency-Key header required") if idempotency_key.empty?
    return error("Idempotency-Key too long") if idempotency_key.length > 255

    payload = normalize_payload
    return error("payload must be a JSON object") unless payload

    result = RequestSubmission.new(idempotency_key: idempotency_key, payload: payload).call
    Result.new(request: result.request, created: result.created, conflict: result.conflict)
  end

  private

  attr_reader :idempotency_key, :payload_param

  def normalize_payload
    return payload_param.to_unsafe_h if payload_param.is_a?(ActionController::Parameters)
    return payload_param if payload_param.is_a?(Hash)

    nil
  end

  def error(message)
    Result.new(error_message: message)
  end
end
