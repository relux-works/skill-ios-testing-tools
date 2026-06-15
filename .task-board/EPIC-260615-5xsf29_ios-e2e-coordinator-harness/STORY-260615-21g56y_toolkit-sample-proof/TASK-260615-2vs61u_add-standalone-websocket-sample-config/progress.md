## Status
done

## Assigned To
codex

## Created
2026-06-15T10:23:00Z

## Last Update
2026-06-15T11:40:07Z

## Blocked By
- TASK-260615-3si6h9

## Blocks
- TASK-260615-1jj8m2

## Checklist
- [x] Define sample coordinator host/port and artifact path
- [x] Define at least three fake peers with stable names and roles
- [x] Keep sample config project-neutral

## Notes
Added project-neutral Samples/IOSE2ECoordinator/sample-three-peer.yaml with dynamic local WebSocket coordinator, repo .temp artifacts, delivery defaults, and alpha/beta/observer process peers. Verification: ios-e2e-runner sample smoke passed with artifacts under .temp/e2e-sample/sample-session-fixed; product-specific grep clean.

## Precondition Resources
(none)

## Outcome Resources
- [TASK-260615-2vs61u_sample-config-results.md](file://TASK-260615-2vs61u/TASK-260615-2vs61u_sample-config-results.md) — Standalone sample config results
