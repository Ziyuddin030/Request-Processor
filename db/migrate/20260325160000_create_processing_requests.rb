# frozen_string_literal: true

class CreateProcessingRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :processing_requests do |t|
      t.string :idempotency_key, null: false
      t.string :request_hash, null: false
      t.json :payload, null: false
      t.json :result
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0

      t.datetime :processing_started_at
      t.datetime :processed_at
      t.datetime :last_failed_at
      t.datetime :cancelled_at

      t.string :last_error_class
      t.text :last_error_message

      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :processing_requests, :idempotency_key, unique: true
    add_index :processing_requests, :status
    add_index :processing_requests, :processing_started_at
  end
end
