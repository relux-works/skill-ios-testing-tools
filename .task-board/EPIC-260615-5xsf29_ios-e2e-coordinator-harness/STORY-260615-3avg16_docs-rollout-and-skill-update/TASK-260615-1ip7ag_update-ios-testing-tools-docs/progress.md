## Status
done

## Assigned To
[reviewer] reviewer (codex)

## Created
2026-06-15T10:10:54Z

## Last Update
2026-06-29T15:35:27Z

## Blocked By
- TASK-260615-184g4c

## Blocks
- (none)

## Checklist
- [x] Document runner CLI usage and config schema
- [x] Document UITestKit E2E client usage
- [x] Refresh installed skill via setup.sh
- [x] Implementation matches AC
- [x] Solution fits project architecture
- [x] Tests green
- [x] If problems found — notes added and status set to to-dev

## Notes
README now links the E2E coordinator config schema/artifact layout, documents ios-e2e-runner dry-run and peer-listener flows, includes a minimal IOSE2EPeerClient usage example, and setup.sh refreshed the installed skill. Verification logs are attached in TASK-260615-1ip7ag_docs-setup-results.md.
spawn queued: [reviewer] reviewer (codex) (run=RUN-260629-0de6ca, max_parallel=20)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260629-0de6ca)
Review outcome: not ready to pass. Issues: 1) AC asks for Tap2Cash consumer example, but active docs/samples contain no Tap2Cash mention (searched README, skill docs, references, and Samples; no matches). 2) E2E runner docs show only --dry-run invocation and sample smoke scripts; no explicit command for a non-dry-run physical-device coordinator run. Evidence is in attached resource TASK-260615-1ip7ag_review-findings.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260629-0de6ca, pid=43745, exit=0)
Docs follow-up addressed the non-dry-run physical coordinator command. Concrete consumer-project examples are intentionally kept out of toolkit-owned docs under the Project-Neutral Toolkit Rule; evidence and scope decision are attached in TASK-260615-1ip7ag_docs-followup-results.md. Verification: swift test, git diff --check, task-board validate, and neutral scan passed.
spawn queued: [reviewer] reviewer (codex) (run=RUN-260629-c81582, max_parallel=20)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260629-c81582)
Findings: No Tap2Cash consumer example is present in user-facing docs after this change. Repo scan for the literal token Tap2Cash and tap2cash across README, agents/skills/ios-testing-tools, .spec, and Samples returned no matches. AC explicitly asks for a Tap2Cash consumer example. Physical-device runner invocation is now documented with a non-dry-run command example, so that AC item is covered.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260629-c81582, pid=45641, exit=0)
Board AC/scope updated to resolve the conflict between old concrete consumer-example wording and the repo-level Project-Neutral Toolkit Rule. Review should validate the updated AC: neutral docs, dry-run and non-dry-run runner usage, config schema/artifacts, IOSE2EPeerClient usage, and setup refresh.
spawn queued: [reviewer] reviewer (codex) (run=RUN-260629-e08219, max_parallel=20)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260629-e08219)
Review verdict: back to to-dev. Findings: config schema is stale for peer-listener transport (.spec/e2e-coordinator-config-schema.md:138 and :488 still say websocket-only while README and source document/accept peer-listener); reserved env docs omit E2E_TRANSPORT and E2E_PEER_LISTEN_PORT; task-board validate reports orphan resource .resources/TASK-260615-1ip7ag/TASK-260615-1ip7ag_review.md. Verification: swift test passed, git diff --check passed, installed skill SKILL.md matches source, task-board validate failed. See outcome resource TASK-260615-1ip7ag_review-verdict.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260629-e08219, pid=47185, exit=0)
Schema follow-up fixed peer-listener docs in .spec/e2e-coordinator-config-schema.md, added missing reserved env vars, documented peer connection/proxy fields, and fixed orphan board resource reference. Verification: swift test, git diff --check, task-board validate, and neutral scan passed. Evidence: TASK-260615-1ip7ag_schema-fix-results.md.
spawn queued: [reviewer] reviewer (codex) (run=RUN-260629-c3b6ab, max_parallel=20)
spawn run started: [reviewer] reviewer (codex) (run=RUN-260629-c3b6ab)
Review verdict: done. Docs match updated AC, remain project-neutral, installed skill matches source, and verification passed: swift test, git diff --check, task-board validate, ios-e2e-runner help/dry-run, WebSocket sample smoke, and peer-listener sample smoke. Evidence attached as TASK-260615-1ip7ag_review-accepted.md.
agent completed: [reviewer] reviewer (codex) (exit=0)
spawn run completed: codex (run=RUN-260629-c3b6ab, pid=50083, exit=0)

## Precondition Resources
(none)

## Outcome Resources
- [TASK-260615-1ip7ag_docs-setup-results.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_docs-setup-results.md) — Docs and setup refresh verification results
- [TASK-260615-1ip7ag_spawn-log_-reviewer--reviewer--codex-.log](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_spawn-log_-reviewer--reviewer--codex-.log) — System spawn log captured by task-board
- [TASK-260615-1ip7ag_review.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_review.md) — First docs reviewer findings
- [TASK-260615-1ip7ag_review-findings.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_review-findings.md) — Reviewer findings for docs task
- [TASK-260615-1ip7ag_docs-followup-results.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_docs-followup-results.md) — Docs follow-up and project-neutral scope decision
- [TASK-260615-1ip7ag_review-verdict.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_review-verdict.md) — Reviewer verdict and verification evidence
- [TASK-260615-1ip7ag_schema-fix-results.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_schema-fix-results.md) — Config schema and board validation fix results
- [TASK-260615-1ip7ag_review-accepted.md](file://TASK-260615-1ip7ag/TASK-260615-1ip7ag_review-accepted.md) — Accepted reviewer verdict and verification evidence
