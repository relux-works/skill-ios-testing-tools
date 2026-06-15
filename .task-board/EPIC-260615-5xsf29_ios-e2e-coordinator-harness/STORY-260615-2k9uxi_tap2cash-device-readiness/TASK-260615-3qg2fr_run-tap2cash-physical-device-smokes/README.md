# TASK-260615-3qg2fr: run-tap2cash-physical-device-smokes

## Description
Run lightweight physical iOS device readiness smokes for the two Tap2Cash test phones with explicit Xcode developer directory, capture trust/tunnel status, and record artifacts before coordinator validation.

## Scope
Run read-only device readiness commands for Tap2Cash physical iOS peers and record trust, lock, tunnel, and connectivity status. No source changes.

## Acceptance Criteria
Both configured iOS peers have captured xcdevice/devicectl evidence. Any trust, lock, tunnel, or connectivity blocker is recorded with command logs. No Tap2Cash source files are modified by this task.
