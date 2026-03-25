# Request Processor (Rails Assignment)

This service implements an idempotent, retry-safe request processor with background jobs, status tracking, cancellation, and concurrency controls.

## Why This Design

- **Idempotency**: `Idempotency-Key` + `request_hash` guarantees duplicate requests don’t duplicate work.
- **Concurrency safety**: row-level locks and optimistic locking avoid race conditions.
- **Retry control**: retryable failures re-enqueue without duplicate processing.
- **Clear state transitions**: explicit status machine ensures predictable behavior.

## Quick Start

1. Install dependencies (requires network access):

```bash
bundle install
```

2. Create database and run migrations:

```bash
bin/rails db:create db:migrate
```

3. Run the server:

```bash
bin/rails server
```

Jobs run via the async adapter in development.

## Test Suite

This project uses RSpec.

```bash
bundle exec rspec
```

## API

### Create Request

```
POST /requests
Headers:
  Idempotency-Key: <unique-key>
Body:
{
  "payload": {
    "order_id": "A-100",
    "amount": 4999
  }
}
```

Responses:
- `202 Accepted`: request queued/processing
- `200 OK`: request already completed
- `409 Conflict`: same idempotency key used with different payload
- `400 Bad Request`: missing/invalid input

### Show Request

```
GET /requests/:id
```

### Cancel Request

```
POST /requests/:id/cancel
```

Returns `200 OK` if cancelled or already cancelled. Returns `409 Conflict` if already finalized.

## Failure Simulation (for testing edge cases)

You can simulate real-world scenarios via `payload.simulate`:

```json
{
  "payload": {
    "order_id": "A-100",
    "simulate": {
      "delay_seconds": 1.5,
      "failure_mode": "flaky",
      "failures_before_success": 2
    }
  }
}
```

- `failure_mode: retryable` -> raises retryable error and is retried
- `failure_mode: non_retryable` -> fails immediately without retry
- `failure_mode: flaky` + `failures_before_success` -> fails N times then succeeds

## Data Model

`ProcessingRequest` fields:
- `idempotency_key` (unique)
- `request_hash` (payload fingerprint)
- `status` (`pending`, `processing`, `retrying`, `completed`, `failed`, `cancelled`)
- `attempts`, timestamps, error info, and `result`

## Notes on ACID/SOLID/DRY/COC

- **ACID**: DB constraints + transactions for creation and safe retries.
- **SOLID**: controller handles HTTP, services handle business logic, job handles orchestration.
- **DRY**: shared serialization and canonical JSON hashing.
- **COC**: Rails conventions preserved.

## Architecture Doc

See `docs/ARCHITECTURE.md` for a full explanation of design decisions and principles covered.

## Future Improvements (Optional)

- Replace async adapter with Solid Queue or Sidekiq in production.
- Add request validation schema.
- Add metrics and structured logging.
