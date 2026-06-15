# TASK-260615-184g4c: validate-generalization-against-tap2cash

## Description
Apply the new coordinator to Tap2Cash as the first consumer and verify that all reusable behavior stays in UITestToolkit while Tap2Cash provides only config, peer mapping, test selectors, environment values, and UI scenario code.

## Scope
Validate the toolkit design against Tap2Cash as a consumer and record any coupling. Prefer dry-run first, then physical run after device readiness.

## Acceptance Criteria
Generalization review documents any Tap2Cash-specific assumption found in the toolkit. Passing criteria: no Tap2Cash domain names or transfer semantics in toolkit core/client/runner; Tap2Cash-specific content stays in the Tap2Cash config or test target.
