# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_25_160000) do
  create_table "processing_requests", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.string "last_error_class"
    t.text "last_error_message"
    t.datetime "last_failed_at"
    t.integer "lock_version", default: 0, null: false
    t.json "payload", null: false
    t.datetime "processed_at"
    t.datetime "processing_started_at"
    t.string "request_hash", null: false
    t.json "result"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_processing_requests_on_idempotency_key", unique: true
    t.index ["processing_started_at"], name: "index_processing_requests_on_processing_started_at"
    t.index ["status"], name: "index_processing_requests_on_status"
  end
end
