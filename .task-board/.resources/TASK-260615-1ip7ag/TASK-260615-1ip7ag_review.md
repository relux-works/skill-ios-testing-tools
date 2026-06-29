# TASK-260615-1ip7ag Review

## Verdict
Needs follow-up (`to-dev`).

## Findings

1. Missing Tap2Cash consumer example
- The task AC explicitly requires "plus a Tap2Cash consumer example".
- Current repo scan found no `Tap2Cash` strings in user-facing docs and samples:
  - `README.md` (task-facing runner docs)
  - `agents/skills/ios-testing-tools/SKILL.md`
  - `agents/skills/ios-testing-tools/references/*`
  - `Samples/IOSE2ECoordinator/*.yaml`
- Scope/goal text in this task still references Tap2Cash, but actual docs now removed all Tap2Cash consumer details.

2. `ios-e2e-runner` physical run flow is not documented as an executable command path
- `README.md` currently documents dry-run:
  - `swift run ios-e2e-runner ... --config ... --dry-run ...`
- No corresponding non-dry-run config-driven physical-device run example is documented in the same section; it jumps from dry-run to sample smoke scripts.
- This leaves “how to run ... physical-device validation” ambiguous, despite AC requiring explicit docs for both dry-run and physical-device verification.

## Evidence
- Search: `rg -n "Tap2Cash|tap2cash" README.md .spec agents/skills/ios-testing-tools` returned no matches.
- Search: `rg -n "swift run ios-e2e-runner" README.md` shows the only documented invocation is the dry-run example.
- Git diff reviewed:
  - `README.md`
  - `agents/skills/ios-testing-tools/SKILL.md`
  - `agents/skills/ios-testing-tools/references/physical-ios-ios-e2e-sync.md`
  - `agents/skills/ios-testing-tools/references/physical-ios-ios-runner-marker-sync.md`
