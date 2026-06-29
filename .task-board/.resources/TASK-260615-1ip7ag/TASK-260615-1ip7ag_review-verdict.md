# TASK-260615-1ip7ag Review Verdict

Verdict: back to `to-dev`.

## Findings

1. Config schema is stale for the implemented/documented peer-listener transport.

   `README.md:246-254` and `agents/skills/ios-testing-tools/SKILL.md` document `coordinator.transport: peer-listener`, and source validation accepts it in `Sources/IOSE2ERunner/E2ERunner.swift:245-247`. However `.spec/e2e-coordinator-config-schema.md:138` still says the transport MVP value is only `websocket`, and `.spec/e2e-coordinator-config-schema.md:488` says configs must reject any transport that is not `websocket`. The same schema also does not document the peer `connection` block used by peer-listener examples. This violates the task requirement to document the runner config schema.

2. Reserved environment documentation is incomplete.

   `README.md:172` points readers to `.spec/e2e-coordinator-config-schema.md` for reserved environment keys. The schema table at `.spec/e2e-coordinator-config-schema.md:333-347` omits `E2E_TRANSPORT` and `E2E_PEER_LISTEN_PORT`, while the runner injects them at `Sources/IOSE2ERunner/E2ERunner.swift:491` and `Sources/IOSE2ERunner/E2ERunner.swift:495-497`, and the UI test client parses them. This leaves the documented client/config contract incomplete.

3. Board validation is not green.

   `task-board validate` reported an orphan resource file: `.resources/TASK-260615-1ip7ag/TASK-260615-1ip7ag_review.md`. The log is `.temp/TASK-260615-1ip7ag-review/task-board-validate-01.log`.

## Verification

- `swift test` passed: 38 tests in 4 suites. Log: `.temp/TASK-260615-1ip7ag-review/swift-test-01.log`.
- `git diff --check` passed. Log: `.temp/TASK-260615-1ip7ag-review/git-diff-check-01.log`.
- Installed skill source check passed: `agents/skills/ios-testing-tools/SKILL.md` matches `~/.agents/skills/ios-testing-tools/SKILL.md`. Log: `.temp/TASK-260615-1ip7ag-review/installed-skill-cmp-01.log`.
- `task-board validate` failed with the orphan resource issue above.
