# STORY-260615-3lefgg: tap2cash-config-consumer-slice

## Description
After the standalone toolkit sample passes, add a config-only Tap2Cash validation slice for the new coordinator while preserving the existing Tap2Cash physical e2e scripts until the new harness is proven.

## Scope
Tap2Cash consumer validation only after standalone sample proof: add config and minimal invocation glue, then validate generalization. Existing Tap2Cash scripts remain intact.

## Acceptance Criteria
Tap2Cash integration starts only after toolkit sample proof. Integration adds config and minimal invocation glue only; existing Tap2Cash e2e scripts remain unchanged. Generalization review confirms no Tap2Cash domain semantics leak into toolkit core/client/runner.
