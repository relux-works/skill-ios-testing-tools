# BUG-260615-i7n5i6: websocket-runner-hangs-after-passed-session

## Description
The WebSocket sample smoke can write a passed session summary and peer logs, but ios-e2e-runner does not exit and keeps the coordinator LISTEN socket open. This blocks release smoke validation and can leave dangling processes.

## Scope
(define bug scope / affected area)

## Acceptance Criteria
(define fix acceptance criteria)
