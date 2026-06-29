# TASK-260615-184g4c Review

Verdict: to-dev

## What Passed

- `swift test` passed: 38 tests in 4 suites. Log: `.temp/TASK-260615-184g4c/swift-test-01.log`.
- Reviewer reran toolkit dry-run against the Tap2Cash generated config. It passed and injected peer-specific coordinator URLs:
  - `peer-a`: `ws://169.254.14.34:8123/e2e/session`
  - `peer-b`: `ws://169.254.228.136:8123/e2e/session`
  - Log: `.temp/TASK-260615-184g4c/tap2cash-dry-run-usb-01.log`.
- Coordinator core/client/runner scan found no Tap2Cash/cash/payment/money/payer/payee terms and no transfer terms.
- Physical attempt evidence reached both Tap2Cash UI test runner processes after device readiness, then failed before coordinator events with `NSURLErrorDomain Code=-1009`; event and receipt logs were empty. This is documented as external network reachability, not toolkit coupling.

## Finding Blocking Acceptance

The task says to record generalization findings and remaining coupling, and the repo-level Project-Neutral Toolkit Rule forbids product-specific names in toolkit-owned source and skill docs.

Static scan still found Tap2Cash names in toolkit-owned artifacts:

- `Sources/IOSDeviceBuild/main.swift:194`
- `Sources/IOSDeviceBuild/main.swift:196`
- `Sources/IOSDeviceBuild/main.swift:197`
- `agents/skills/ios-testing-tools/SKILL.md:432`

These are outside coordinator core/client/runner, so they do not invalidate the narrow coordinator implementation. They do prevent accepting this task as a complete generalization review because remaining Tap2Cash coupling was not recorded/neutralized.

## Required Rework

Neutralize those examples/docs to project-neutral placeholders or explicitly record a scoped decision on the board if they are intentionally out of scope. Then rerun:

- `swift test`
- Tap2Cash config dry-run with `ios-e2e-runner --dry-run`
- static leak scan excluding `.temp/**` and `.task-board/**`
