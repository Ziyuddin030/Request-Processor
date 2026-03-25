# Architecture & Rationale

This document explains what we built, why each choice was made, and which principles are covered (SOLID, ACID, DRY, COC). It is written to be readable by reviewers and future maintainers.

## Problem Summary

We needed a Rails API that:
- Accepts requests via REST API
- Processes work asynchronously
- Prevents duplicate processing (idempotency)
- Handles retries and failures safely
- Supports cancellation
- Behaves correctly under concurrency and race conditions

Requirements were intentionally incomplete, so the design prioritizes resilience, clarity, and explicit behavior under edge cases.

## High‑Level Design

We implemented a request lifecycle with explicit states and background processing.

**Lifecycle**
1. `POST /requests` accepts a payload with an `Idempotency-Key` header.
2. The request is persisted in `processing_requests` and enqueued.
3. A background job transitions the request to `processing` and executes work.
4. Results and errors are stored and the status is updated.
5. `GET /requests/:id` returns the current state.
6. `POST /requests/:id/cancel` cancels if not yet finalized.

## Data Model

`ProcessingRequest` stores everything needed for idempotency and observability:
- `idempotency_key` (unique)
- `request_hash` (hash of canonical payload)
- `status` (`pending`, `processing`, `retrying`, `completed`, `failed`, `cancelled`)
- `attempts`, timestamps, `result`, and error info

A unique index on `idempotency_key` is the first line of defense against duplicates.

## Key Components

### 1) Controller Layer
- `ProcessingRequestsController` validates input, enforces idempotency, and renders consistent responses.
- Any invalid/malformed input returns `400` with a clear error.

### 2) Service Layer
- `RequestSubmission` handles idempotent creation and conflict detection.
- `CanonicalJson` ensures payloads are hashed deterministically to detect duplicate keys with different data.
- `RequestProcessing::Processor` encapsulates the processing logic and simulated failures.

### 3) Job Layer
- `ProcessRequestJob` orchestrates state transitions and retry behavior.
- Uses row locks (`with_lock`) and retry policies to stay safe under concurrency.

### 4) Errors
- `RequestProcessingErrors` defines retryable vs non‑retryable errors in a stable, autoloadable place.

## Concurrency & Idempotency

We combine three layers of safety:
1. **DB constraint**: unique index on `idempotency_key` prevents duplicates at the database level.
2. **Request hash**: same idempotency key + different payload returns `409 Conflict`.
3. **Row locking**: `with_lock` ensures only one worker can process a request at a time.

This prevents duplicate processing even under concurrent requests or multiple workers.

## Retry Strategy

- Retryable failures raise `RetryableError` and are retried with backoff.
- Non‑retryable failures fail immediately and stop retries.
- Max attempts are enforced in both job retry policy and DB state.

This ensures no duplicate processing across retries and avoids infinite loops.

## Cancellation Strategy

Cancellation is allowed only while `pending`, `processing`, or `retrying`.
A cancellation is treated as terminal and the job checks the flag before and after processing.

## Principles Covered

### SOLID
- **S**: Single Responsibility
  - Controller handles HTTP, service handles business logic, job handles orchestration.
- **O**: Open/Closed
  - Processing logic can be extended without changing job/controller logic.
- **L**: Liskov Substitution
  - Retryable/non‑retryable errors can be extended without breaking job behavior.
- **I**: Interface Segregation
  - Small focused services avoid large monolithic classes.
- **D**: Dependency Inversion
  - Job depends on abstractions (processor + error types), not direct controller logic.

### ACID
- **Atomicity**: state changes occur inside transactions or row locks.
- **Consistency**: DB constraints enforce unique idempotency keys and status validity.
- **Isolation**: row locking avoids concurrent state corruption.
- **Durability**: all state and results persisted in DB.

### DRY
- Canonical JSON hashing prevents duplicate payload logic in multiple places.
- Shared serialization is centralized in controller.

### COC (Convention Over Configuration)
- Standard Rails folders and conventions used (`app/services`, `app/jobs`, `app/controllers`).
- Rails defaults preserved wherever possible.

## Edge Cases Addressed

- Duplicate requests with same idempotency key
- Same key used with different payload
- Retry duplication
- Downstream failures (retryable vs non‑retryable)
- Cancellation mid‑processing
- Concurrency races and simultaneous submissions

## Testing Approach (RSpec)

- Request specs verify API behavior and idempotency.
- Job specs verify processing success, failure, and cancellation behavior.

## What You Can Extend Next

- Swap async adapter with Solid Queue or Sidekiq in production.
- Add JSON schema validation for payloads.
- Add structured logging or metrics for observability.
