# frozen_string_literal: true

require "digest"

class RequestSubmission
  Result = Struct.new(:request, :created, :conflict, keyword_init: true)

  def initialize(idempotency_key:, payload:)
    @idempotency_key = idempotency_key
    @payload = payload
    @request_hash = Digest::SHA256.hexdigest(CanonicalJson.dump(payload))
  end

  def call
    existing = ProcessingRequest.find_by(idempotency_key: idempotency_key)

    if existing
      return Result.new(request: existing, created: false, conflict: true) if existing.request_hash != request_hash
      return Result.new(request: existing, created: false, conflict: false)
    end

    request = ProcessingRequest.create!(
      idempotency_key: idempotency_key,
      request_hash: request_hash,
      payload: payload,
      status: "pending"
    )

    Result.new(request: request, created: true, conflict: false)
  rescue ActiveRecord::RecordNotUnique
    # Race: another request created the same idempotency key.
    existing = ProcessingRequest.find_by!(idempotency_key: idempotency_key)
    return Result.new(request: existing, created: false, conflict: true) if existing.request_hash != request_hash

    Result.new(request: existing, created: false, conflict: false)
  end

  private

  attr_reader :idempotency_key, :payload, :request_hash
end
