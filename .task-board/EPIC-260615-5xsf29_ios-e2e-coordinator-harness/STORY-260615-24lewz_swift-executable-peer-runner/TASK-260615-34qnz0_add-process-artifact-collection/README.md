# TASK-260615-34qnz0: add-process-artifact-collection

## Description
Add artifact collection for each E2E session: per-peer xcodebuild logs, xcresult bundles, coordinator event log, session summary, config copy, and extracted screenshots where available.

## Scope
Persist per-session and per-peer evidence from runner and coordinator: config copy, event log, receipt log, xcodebuild logs, xcresult paths, screenshots where available, and summary JSON.

## Acceptance Criteria
Runner writes a deterministic artifact layout under the configured run directory. Artifact paths are included in the session summary and failures preserve enough logs to diagnose the last observed peer state.
