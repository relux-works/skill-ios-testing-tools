# TASK-260615-1mythx: add-tap2cash-e2e-coordinator-config

## Description
Add a Tap2Cash config-only consumer slice for the new E2E coordinator on the feature branch: host/port, two physical iOS peers, peer names, device ids, test selectors, and project-specific environment values.

## Scope
Add Tap2Cash consumer config and minimal invocation glue after sample proof. Map physical device ids to stable peer names and roles without changing legacy scripts.

## Acceptance Criteria
Tap2Cash integration adds config and minimal invocation glue only. Existing Tap2Cash e2e scripts remain unchanged. The config maps both physical devices to stable peer names and can be used by the toolkit runner dry-run.
