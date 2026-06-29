# Flight Logbook

> Institutional memory. Concise, factual, high-signal.
> Newest entries first. One block per insight.

## 2026-06-29

### 1834 — TASK-260615-1ip7ag Review Findings
- FINDING: reviewer requested a concrete consumer-project example in toolkit docs, but the repo-level project-neutral rule forbids product-specific examples in toolkit-owned docs.
- FIX: keep concrete consumer validation evidence in task-board resources or the consumer repo; keep README/skill docs neutral.
- FIX: add an explicit non-dry-run `ios-e2e-runner` physical-device command path to `README.md`.
- DECISION: updated docs task/story AC to exclude concrete consumer examples from toolkit-owned docs and point those examples to consumer repositories or board outcome resources.

### 1826 — TASK-260615-1ip7ag Schema Drift
- FINDING: `.spec/e2e-coordinator-config-schema.md:138` and `.spec/e2e-coordinator-config-schema.md:488` still describe only `websocket`, while `README.md:246` and `Sources/IOSE2ERunner/E2ERunner.swift:245` document/accept `peer-listener`.
- FINDING: reserved environment docs omit `E2E_TRANSPORT` and `E2E_PEER_LISTEN_PORT`, both injected by `Sources/IOSE2ERunner/E2ERunner.swift:491` and `Sources/IOSE2ERunner/E2ERunner.swift:495`.
- FIX: schema now documents `peer-listener`, peer `connection`, proxy fields, reserved peer-listener environment values, and matching validation rules.
- STATUS: `swift test`, `git diff --check`, `task-board validate`, and neutral scan pass after schema fix.

## 2026-06-29

### 1756 — Consumer Neutrality Cleanup
- FIX: Neutralized consumer-project examples in `Sources/IOSDeviceBuild/main.swift`, `agents/skills/ios-testing-tools/SKILL.md`, and `agents/skills/ios-testing-tools/references/physical-ios-ios-runner-marker-sync.md`.
- STATUS: Source/skill leak scans are empty after cleanup; consumer config remains intentionally product-specific outside toolkit-owned artifacts.

### 1748 — Consumer Neutrality Leak
- FINDING: `TASK-260615-184g4c` review found no consumer-project terms in coordinator core/client/runner, but repo-level neutral scans still found consumer-project names in toolkit-owned artifacts.
- SCOPE: `Sources/IOSDeviceBuild/main.swift:194`, `Sources/IOSDeviceBuild/main.swift:196`, `Sources/IOSDeviceBuild/main.swift:197`, `agents/skills/ios-testing-tools/SKILL.md:432`.
- STATUS: Pending developer cleanup or explicit board-recorded scope decision before accepting the generalization validation task.
