# TASK-260615-aqo26k: enforce-project-neutral-toolkit-instructions

## Description
Add repo-local instruction guard that ios-testing-tools is a generalized toolkit and must not absorb product-project-specific semantics, names, flows, or assumptions.

## Scope
Repo-local instruction change only. Add a root AGENTS.md guard that ios-testing-tools is a reusable toolkit and all toolkit-owned specs, diagrams, docs, source, tests, and samples must remain project-neutral.

## Acceptance Criteria
AGENTS.md exists at the skill-ios-testing-tools repo root and explicitly forbids product-project-specific names, domain events, flows, bundle ids, device names, and assumptions in toolkit artifacts. It points product-specific validation to consumer repos/config/tests only.
