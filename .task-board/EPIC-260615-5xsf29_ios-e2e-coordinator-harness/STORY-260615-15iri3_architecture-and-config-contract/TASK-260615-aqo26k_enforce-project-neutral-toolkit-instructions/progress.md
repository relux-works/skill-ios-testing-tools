## Status
done

## Assigned To
codex

## Created
2026-06-15T10:54:27Z

## Last Update
2026-06-15T10:55:12Z

## Blocked By
- (none)

## Blocks
- (none)

## Checklist
- [x] Add root AGENTS.md with project-neutral toolkit rule
- [x] Verify instruction text contains no product-specific names
- [x] Validate board after instruction update

## Notes
Added ignored root AGENTS.md local instruction file and mirrored the content as a board outcome resource because AGENTS.md is intentionally gitignored in this repo.

Strengthened the local instruction guard to make the toolkit-first generalization boundary explicit: consumer product domains may validate the toolkit, but product language, workflows, fixtures, app identifiers, device names, and migration details must not become toolkit defaults, public APIs, samples, specs, or diagrams.

## Precondition Resources
(none)

## Outcome Resources
- [TASK-260615-aqo26k_project-neutral-agents-instructions.md](file://TASK-260615-aqo26k/TASK-260615-aqo26k_project-neutral-agents-instructions.md) — Repo-local project-neutral toolkit instruction guard
