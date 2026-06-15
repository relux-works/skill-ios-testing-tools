# STORY-260615-2k9uxi: tap2cash-device-readiness

## Description
Verify physical iOS devices and Tap2Cash app-side smoke readiness before validating the new coordinator harness on real devices.

## Scope
Physical-device readiness only for Tap2Cash validation: device discovery, trust, lock state, tunnel readiness, and captured logs. No source changes in Tap2Cash.

## Acceptance Criteria
Both Tap2Cash physical iOS peers have xcdevice/devicectl readiness evidence before physical coordinator validation. Any trust, lock, tunnel, or connectivity blocker is recorded with artifact paths.
