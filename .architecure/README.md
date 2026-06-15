# E2E Coordinator Architecture

This directory contains diagrams-as-code for `EPIC-260615-5xsf29 ios-e2e-coordinator-harness`.

The directory name intentionally follows the requested project-local artifact path `.architecure`.

## Diagrams

- `e2e-coordinator-components.puml` - static component/module boundaries for the reusable toolkit, standalone sample, and a generic consumer project.
- `e2e-session-event-flow.puml` - runtime WebSocket sequence for a multi-peer E2E session.
- `e2e-peer-session-state.puml` - session and peer lifecycle state model.

## Rendering

Render with PlantUML:

```bash
java -jar .temp/plantuml.jar -tsvg .architecure/*.puml
```

or any PlantUML-compatible IDE/plugin.

## Board Mapping

- `TASK-260615-59f5jb write-e2e-coordinator-design` owns the architecture narrative.
- `TASK-260615-3si6h9 define-peer-config-schema` owns the config contract.
- `TASK-260615-1zlpve implement-session-event-core` owns the coordinator core.
- `TASK-260615-27ds5k implement-uitestkit-e2e-client` owns the UI test client.
- `TASK-260615-b5oyjr implement-ios-e2e-runner-cli` owns peer launch and supervision.
- `STORY-260615-21g56y toolkit-sample-proof` owns the standalone sample proof before any consumer integration.
- Consumer integration tasks own project-specific config proof outside the generalized architecture diagrams.
