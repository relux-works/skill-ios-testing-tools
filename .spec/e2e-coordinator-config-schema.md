# E2E Coordinator Config Schema

## Goal

Define a project-neutral configuration contract for the reusable iOS E2E coordinator harness.

The config tells the toolkit runner how to start a session, where to bind the local WebSocket coordinator, how to launch peers, which peer identity each run receives, and where to write artifacts. Product scenario semantics remain in consumer UI tests and are represented in config only as opaque event names, selectors, environment values, or metadata.

## Format

MVP authoring format is YAML. The parsed model must also be representable as JSON for tests, diagnostics, and generated run summaries.

Durations are strings with explicit units:

- `ms`
- `s`
- `m`

Paths are resolved relative to the config file unless they are absolute.

Unknown top-level fields are invalid. Project-specific values belong under `metadata` or peer-specific `appEnvironment`.

## Top-Level Shape

```yaml
schemaVersion: 1
profileName: local-two-peer

session:
  name: multi-peer-ui-e2e
  idPrefix: e2e
  metadata:
    owner: ui-tests

coordinator:
  bindHost: 0.0.0.0
  advertisedHost: auto
  port: 0
  path: /e2e/session
  transport: websocket

artifacts:
  root: .temp/e2e-runs/${sessionId}
  keepSuccessfulRuns: true
  writeResolvedConfig: true
  writeEventLog: true
  writeReceipts: true
  collectXcresults: true
  collectScreenshots: true

defaults:
  timeout: 60s
  heartbeatInterval: 5s
  reconnectWindow: 30s
  payloadFormat: json
  delivery:
    publishRequirement: accepted
    ackTimeout: 10s
    broadcast: exceptPublisher
  xcodebuild:
    developerDir: /Applications/Xcode.app/Contents/Developer
    derivedDataRoot: .temp/e2e-derived-data/${sessionId}

peers:
  - name: alpha
    role: primary
    launch:
      kind: xctest
      startWhen:
        type: immediate
    xctest:
      workspace: App.xcworkspace
      scheme: AppUITests
      destination:
        platform: iOS
        id: 00000000-0000000000000000
      onlyTesting:
        - AppUITests/AlphaPeerTests/testScenario
    appEnvironment:
      APP_E2E_MODE: "1"

  - name: beta
    role: secondary
    launch:
      kind: xctest
      startWhen:
        type: event
        event:
          name: alpha.ready
          fromPeer: alpha
          timeout: 60s
    xctest:
      workspace: App.xcworkspace
      scheme: AppUITests
      destination:
        platform: iOS
        id: 11111111-1111111111111111
      onlyTesting:
        - AppUITests/BetaPeerTests/testScenario
```

## Fields

### `schemaVersion`

Required integer. MVP value is `1`.

The runner must reject unsupported versions before launching peers.

### `profileName`

Required string used in logs, artifact summaries, and run labels.

Use separate config files for materially different launch profiles in the MVP. A future overlay mechanism can be added after the core runner is stable.

### `session`

Required object.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes | Human-readable session family name. |
| `idPrefix` | string | no | Prefix used when the runner generates `sessionId`. Default: `e2e`. |
| `metadata` | JSON object | no | Project-neutral metadata copied into summaries. |

The runner generates the concrete `sessionId`. Config must not hard-code it.

### `coordinator`

Required object.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `bindHost` | string | yes | Local host/interface used by the Mac coordinator process. |
| `advertisedHost` | string | yes | Host peers use to connect. `auto` means runner resolves a reachable host address. |
| `port` | integer | yes | WebSocket port. `0` means choose a free port and inject the resolved URL into peers. |
| `path` | string | no | WebSocket path. Default: `/e2e/session`. |
| `transport` | enum | yes | MVP value: `websocket`. |

Physical iOS devices usually cannot connect to `127.0.0.1` on the Mac. Use `advertisedHost: auto` or an explicit LAN address.

### `artifacts`

Required object.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `root` | path template | yes | Run artifact root. Supports `${sessionId}` and `${profileName}`. |
| `keepSuccessfulRuns` | bool | no | Whether successful run artifacts are preserved. Default: `true`. |
| `writeResolvedConfig` | bool | no | Write fully resolved config into artifacts. Default: `true`. |
| `writeEventLog` | bool | no | Write append-only event log. Default: `true`. |
| `writeReceipts` | bool | no | Write publish and delivery receipts. Default: `true`. |
| `collectXcresults` | bool | no | Copy or link peer `.xcresult` bundles. Default: `true` for `xctest` peers. |
| `collectScreenshots` | bool | no | Extract screenshots when available. Default: `true`. |

Artifact layout is deterministic:

```text
<root>/
  resolved-config.json
  session-summary.json
  event-log.jsonl
  receipts.jsonl
  coordinator.log
  peers/
    <peerName>/
      launch.json
      xcodebuild.log
      result.xcresult/
      screenshots/
```

### `defaults`

Optional object. Defaults apply to every peer unless overridden.

| Field | Type | Description |
| --- | --- | --- |
| `timeout` | duration | Generic wait timeout. |
| `heartbeatInterval` | duration | Peer heartbeat cadence. |
| `reconnectWindow` | duration | Time a peer may reconnect with `lastSeenSeq`. |
| `payloadFormat` | enum | MVP value: `json`. |
| `delivery` | object | Default publish receipt behavior. |
| `xcodebuild` | object | Default Xcode command settings. |

#### `defaults.delivery`

| Field | Type | Description |
| --- | --- | --- |
| `publishRequirement` | enum | `accepted`, `enqueued`, `sent`, or `acked`. |
| `ackTimeout` | duration | Timeout for `acked` delivery barriers. |
| `broadcast` | enum | MVP value: `exceptPublisher`. |

`acked` means every required recipient acknowledged the event. Required recipients are selected by the publish API call; if omitted, the coordinator uses currently connected non-publisher peers.

#### `defaults.xcodebuild`

| Field | Type | Description |
| --- | --- | --- |
| `developerDir` | absolute path | Value for `DEVELOPER_DIR`. |
| `derivedDataRoot` | path template | Root for per-peer DerivedData. |
| `configuration` | string | Optional Xcode build configuration. |
| `sdk` | string | Optional SDK override. |

### `peers`

Required non-empty array.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | string | yes | Stable unique peer name injected into the test environment. |
| `role` | string | no | Project-neutral role label for logs and summaries. |
| `metadata` | JSON object | no | Opaque peer metadata copied to summaries. |
| `launch` | object | yes | Launch type and start condition. |
| `xctest` | object | required when `launch.kind=xctest` | Xcode UI test launch settings. |
| `process` | object | required when `launch.kind=process` | Local process launch settings for samples/fake peers. |
| `appEnvironment` | string map | no | Extra environment variables injected into the UI test process. |
| `delivery` | object | no | Peer-specific delivery defaults. |
| `artifacts` | object | no | Peer-specific artifact overrides. |

Peer names must be unique and must match:

```text
^[A-Za-z][A-Za-z0-9_.-]{0,63}$
```

### `launch`

Required object.

```yaml
launch:
  kind: xctest
  startWhen:
    type: event
    event:
      name: alpha.ready
      fromPeer: alpha
      timeout: 60s
```

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `kind` | enum | yes | `xctest` or `process`. |
| `startWhen` | object | yes | Start condition evaluated by the runner. |

#### `startWhen`

Supported MVP forms:

```yaml
startWhen:
  type: immediate
```

```yaml
startWhen:
  type: event
  event:
    name: alpha.ready
    fromPeer: alpha
    timeout: 60s
```

```yaml
startWhen:
  type: manual
```

`event.name` is an opaque string. The coordinator treats it as data and does not parse product semantics.

### `xctest`

Required when `launch.kind` is `xctest`.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `workspace` | path | one of workspace/project | Xcode workspace. |
| `project` | path | one of workspace/project | Xcode project. |
| `scheme` | string | yes | Scheme to test. |
| `testPlan` | string | no | Test plan name. |
| `destination` | object | yes | Xcode destination. |
| `onlyTesting` | string array | no | `-only-testing` entries. |
| `skipTesting` | string array | no | `-skip-testing` entries. |
| `xctestrun` | path | no | Existing `.xctestrun` file for `test-without-building`. |
| `buildForTesting` | bool | no | Whether runner should build before launching. Default: runner-level mode. |

#### `destination`

Physical device by UDID:

```yaml
destination:
  platform: iOS
  id: 00000000-0000000000000000
```

Simulator by name:

```yaml
destination:
  platform: iOS Simulator
  name: iPhone 17 Pro
  os: latest
```

Raw destination fallback:

```yaml
destination:
  raw: platform=iOS,id=00000000-0000000000000000
```

### `process`

Required when `launch.kind` is `process`. Used by standalone samples and local fake peers.

```yaml
process:
  executable: .build/debug/e2e-fake-peer
  arguments:
    - --scenario
    - alpha
  workingDirectory: .
```

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `executable` | path | yes | Local executable path. |
| `arguments` | string array | no | Process arguments. |
| `workingDirectory` | path | no | Process working directory. Default: config directory. |

## Reserved Environment

The runner injects these variables into every peer process:

| Variable | Description |
| --- | --- |
| `E2E_SESSION_ID` | Concrete generated session id. |
| `E2E_PROFILE_NAME` | Config `profileName`. |
| `E2E_PEER_NAME` | Config peer name. |
| `E2E_PEER_ROLE` | Config peer role, if present. |
| `E2E_COORDINATOR_URL` | Resolved WebSocket URL. |
| `E2E_ARTIFACTS_DIR` | Peer artifact directory. |
| `E2E_LAST_SEEN_SEQ` | Initial sequence cursor. Usually `0`. |

Config `appEnvironment` must not define keys with the `E2E_` prefix. The runner rejects collisions.

## Standalone Sample Config

The sample proof uses local process peers and the same coordinator protocol as UI tests:

```yaml
schemaVersion: 1
profileName: sample-local-three-peer

session:
  name: sample-local-three-peer

coordinator:
  bindHost: 127.0.0.1
  advertisedHost: 127.0.0.1
  port: 0
  transport: websocket

artifacts:
  root: .temp/e2e-sample/${sessionId}

defaults:
  timeout: 10s
  payloadFormat: json
  delivery:
    publishRequirement: accepted
    ackTimeout: 2s
    broadcast: exceptPublisher

peers:
  - name: alpha
    role: sample-alpha
    launch:
      kind: process
      startWhen:
        type: immediate
    process:
      executable: .build/debug/e2e-fake-peer
      arguments: ["--peer", "alpha"]

  - name: beta
    role: sample-beta
    launch:
      kind: process
      startWhen:
        type: event
        event:
          name: alpha.ready
          fromPeer: alpha
          timeout: 10s
    process:
      executable: .build/debug/e2e-fake-peer
      arguments: ["--peer", "beta"]

  - name: observer
    role: sample-observer
    launch:
      kind: process
      startWhen:
        type: immediate
    process:
      executable: .build/debug/e2e-fake-peer
      arguments: ["--peer", "observer"]
```

## Two-Device Consumer Config

Consumer projects provide their own UI test selectors and device destinations:

```yaml
schemaVersion: 1
profileName: consumer-two-device

session:
  name: consumer-two-device

coordinator:
  bindHost: 0.0.0.0
  advertisedHost: auto
  port: 0
  transport: websocket

artifacts:
  root: .temp/e2e-consumer/${sessionId}

defaults:
  timeout: 60s
  payloadFormat: json
  delivery:
    publishRequirement: accepted
    ackTimeout: 10s
    broadcast: exceptPublisher
  xcodebuild:
    developerDir: /Applications/Xcode.app/Contents/Developer
    derivedDataRoot: .temp/e2e-derived-data/${sessionId}

peers:
  - name: alpha
    role: primary
    launch:
      kind: xctest
      startWhen:
        type: immediate
    xctest:
      workspace: App.xcworkspace
      scheme: AppUITests
      destination:
        platform: iOS
        id: 00000000-0000000000000000
      onlyTesting:
        - AppUITests/AlphaPeerTests/testScenario
    appEnvironment:
      APP_E2E_MODE: "1"

  - name: beta
    role: secondary
    launch:
      kind: xctest
      startWhen:
        type: event
        event:
          name: alpha.ready
          fromPeer: alpha
          timeout: 60s
    xctest:
      workspace: App.xcworkspace
      scheme: AppUITests
      destination:
        platform: iOS
        id: 11111111-1111111111111111
      onlyTesting:
        - AppUITests/BetaPeerTests/testScenario
```

## Validation Rules

The runner must reject a config before launching peers when:

- `schemaVersion` is unsupported.
- `profileName` is empty.
- `coordinator.transport` is not `websocket`.
- `coordinator.port` is outside `0...65535`.
- `advertisedHost` resolves to localhost while any peer destination is a physical iOS device.
- `peers` is empty.
- Peer names are duplicated or invalid.
- A peer has `launch.kind=xctest` without `xctest`.
- A peer has `launch.kind=process` without `process`.
- `xctest` defines both `workspace` and `project`, or neither.
- `xctest.destination` is missing.
- `startWhen.type=event` references a peer name that is not configured.
- `appEnvironment` overrides a reserved `E2E_` variable.
- Duration fields are missing units or use unsupported units.

## Non-Goals

- No product-specific event taxonomy in toolkit config schema.
- No gRPC transport in schema version `1`.
- No multi-file include or overlay system in the MVP.
- No implicit peer discovery from test names. Peer identity is explicit config plus runner-injected environment.
