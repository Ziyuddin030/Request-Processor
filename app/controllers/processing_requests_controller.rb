# frozen_string_literal: true

class ProcessingRequestsController < ApplicationController
  before_action :load_request, only: %i[show cancel]

  def create
    result = RequestCreation.new(
      idempotency_key: request.headers["Idempotency-Key"],
      payload_param: params.require(:payload)
    ).call

    return render_bad_request(result.error_message) if result.error_message

    if result.conflict
      return render json: { error: "conflict", message: "idempotency key reused with different payload" },
                    status: :conflict
    end

    status = response_status_for(result.request)
    render json: serialize_request(result.request), status: status
  end

  def show
    render json: serialize_request(@processing_request), status: :ok
  end

  def cancel
    if @processing_request.cancelable?
      @processing_request.mark_cancelled!
      return render json: serialize_request(@processing_request), status: :ok
    end

    if @processing_request.cancelled?
      return render json: serialize_request(@processing_request), status: :ok
    end

    render json: { error: "conflict", message: "request already finalized" }, status: :conflict
  end

  private

  def load_request
    @processing_request = ProcessingRequest.find(params[:id])
  end

  def response_status_for(request)
    return :ok if request.completed?
    return :accepted if request.pending? || request.processing? || request.retrying?

    :ok
  end

  def serialize_request(request)
    {
      id: request.id,
      idempotency_key: request.idempotency_key,
      status: request.status,
      attempts: request.attempts,
      payload: request.payload,
      result: request.result,
      error: request.last_error_message,
      created_at: request.created_at,
      processing_started_at: request.processing_started_at,
      processed_at: request.processed_at,
      cancelled_at: request.cancelled_at
    }
  end

  def render_bad_request(message)
    render json: { error: "bad_request", message: message }, status: :bad_request
  end
end
