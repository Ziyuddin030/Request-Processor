# frozen_string_literal: true

class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |exception|
    render json: { error: "bad_request", message: exception.message }, status: :bad_request
  end

  rescue_from JSON::ParserError do
    render json: { error: "bad_request", message: "invalid JSON" }, status: :bad_request
  end

  rescue_from StandardError do |exception|
    Rails.logger.error("Unhandled error: #{exception.class} - #{exception.message}\n#{exception.backtrace&.first(5)&.join("\n")}")
    render json: { error: "internal_server_error" }, status: :internal_server_error
  end
end
