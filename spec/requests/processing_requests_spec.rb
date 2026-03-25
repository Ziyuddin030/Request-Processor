# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ProcessingRequests", type: :request do
  before do
    ProcessingRequest.delete_all
  end

  it "creates a request and enqueues a job" do
    expect do
      post "/requests",
           headers: { "Idempotency-Key" => "key-123" },
           params: { payload: { order_id: "A-100" } },
           as: :json
    end.to have_enqueued_job(ProcessRequestJob)

    expect(response).to have_http_status(:accepted)
    body = JSON.parse(response.body)
    expect(body.fetch("status")).to eq("pending")
  end

  it "reuses idempotency key with same payload" do
    post "/requests",
         headers: { "Idempotency-Key" => "key-dup" },
         params: { payload: { order_id: "A-200" } },
         as: :json

    expect(response).to have_http_status(:accepted)

    expect do
      post "/requests",
           headers: { "Idempotency-Key" => "key-dup" },
           params: { payload: { order_id: "A-200" } },
           as: :json
    end.not_to have_enqueued_job(ProcessRequestJob)

    expect(response).to have_http_status(:accepted)
  end

  it "rejects idempotency key reuse with different payload" do
    post "/requests",
         headers: { "Idempotency-Key" => "key-conflict" },
         params: { payload: { order_id: "A-300" } },
         as: :json

    expect(response).to have_http_status(:accepted)

    post "/requests",
         headers: { "Idempotency-Key" => "key-conflict" },
         params: { payload: { order_id: "A-999" } },
         as: :json

    expect(response).to have_http_status(:conflict)
  end

  it "cancels a request" do
    post "/requests",
         headers: { "Idempotency-Key" => "key-cancel" },
         params: { payload: { order_id: "A-400" } },
         as: :json

    request_id = JSON.parse(response.body).fetch("id")

    post "/requests/#{request_id}/cancel"

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.fetch("status")).to eq("cancelled")
  end
end
