# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessRequestJob, type: :job do
  before do
    ProcessingRequest.delete_all
  end

  it "marks request completed on success" do
    request = ProcessingRequest.create!(
      idempotency_key: "job-success",
      request_hash: "hash",
      payload: { order_id: "A-500" },
      status: "pending"
    )

    expect do
      described_class.perform_now(request.id)
    end.to change { request.reload.status }.from("pending").to("completed")

    expect(request.reload.result.fetch("message")).to eq("processed")
  end

  it "marks request failed on non-retryable error" do
    request = ProcessingRequest.create!(
      idempotency_key: "job-fail",
      request_hash: "hash2",
      payload: { simulate: { failure_mode: "non_retryable" } },
      status: "pending"
    )

    described_class.perform_now(request.id)

    request.reload
    expect(request.status).to eq("failed")
    expect(request.last_error_message).to match(/non-retryable/i)
  end

  it "keeps cancelled requests cancelled" do
    request = ProcessingRequest.create!(
      idempotency_key: "job-cancel",
      request_hash: "hash3",
      payload: { order_id: "A-600" },
      status: "pending"
    )

    request.mark_cancelled!
    described_class.perform_now(request.id)

    expect(request.reload.status).to eq("cancelled")
  end
end
