## Status
done

## Assigned To
codex

## Created
2026-06-15T10:23:00Z

## Last Update
2026-06-15T11:43:25Z

## Blocked By
- TASK-260615-2vs61u
- TASK-260615-2s68ew
- TASK-260615-3f2aw7
- TASK-260615-3jwzhd

## Blocks
- TASK-260615-1mythx
- TASK-260615-3qg2fr

## Checklist
- [x] Add local sample smoke entrypoint
- [x] Verify event log and summary artifacts
- [x] Document sample command in README/skill docs

## Notes
Added Scripts/run-e2e-sample-smoke.sh. Smoke builds e2e-fake-peer, runs ios-e2e-runner with sample-three-peer config, validates summary, event log, receipts, JSON payload, timestamp envelope, replay marker, peer logs, and artifact layout. Also wired WebSocket recorder/file recorder so event-log.jsonl and receipts.jsonl are populated. Verification: sample smoke passed; combined E2E harness suite passed 32 tests; product-specific and Cyrillic greps clean; git diff --check and task-board validate clean.

## Precondition Resources
(none)

## Outcome Resources
- [TASK-260615-1jj8m2_sample-smoke-results.md](file://TASK-260615-1jj8m2/TASK-260615-1jj8m2_sample-smoke-results.md) — Standalone sample smoke command results
