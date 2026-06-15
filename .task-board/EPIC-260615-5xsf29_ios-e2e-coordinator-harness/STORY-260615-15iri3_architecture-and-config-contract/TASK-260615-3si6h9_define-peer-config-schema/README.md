# TASK-260615-3si6h9: define-peer-config-schema

## Description
Define a portable config schema for WebSocket E2E coordinator sessions: host binding, port, peer names, device destinations, roles, test selectors, environment values, delivery defaults, timeouts, artifact paths, and sample/consumer profiles.

## Scope
Specify portable YAML or JSON config fields for coordinator bind address, session defaults, peer identities, destinations, launch selectors, environment values, wait/start predicates, delivery defaults, timeouts, and artifacts.

## Acceptance Criteria
Schema supports standalone sample peers and at least two physical iOS peers, does not encode Tap2Cash-specific domain semantics, can express peer start ordering through event predicates, and can grow to N peers.
