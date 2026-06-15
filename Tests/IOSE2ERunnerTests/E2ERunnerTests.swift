import Foundation
import Testing
@testable import IOSE2ERunner

@Suite
struct E2ERunnerTests {
    @Test
    func parsesCLIOptions() throws {
        let options = try E2ERunnerCLIOptions.parse([
            "ios-e2e-runner",
            "--config", "e2e.yaml",
            "--dry-run",
            "--session-id", "session-1",
            "--developer-dir", "/Applications/Xcode.app/Contents/Developer"
        ])

        #expect(options.configPath == "e2e.yaml")
        #expect(options.dryRun == true)
        #expect(options.sessionID == "session-1")
        #expect(options.developerDir == "/Applications/Xcode.app/Contents/Developer")
    }

    @Test
    func decodesYamlConfig() throws {
        let config = try E2ERunnerConfigLoader.decode(text: yamlConfig(), format: .yaml)

        #expect(config.schemaVersion == 1)
        #expect(config.profileName == "local-two-peer")
        #expect(config.peers.map(\.name) == ["alpha", "beta"])
    }

    @Test
    func rejectsReservedEnvironmentCollisions() throws {
        var config = makeConfig()
        config.peers[0].appEnvironment = ["E2E_SESSION_ID": "override"]

        #expect(throws: E2ERunnerError.invalidConfig("Peer alpha appEnvironment must not define reserved key E2E_SESSION_ID.")) {
            try E2ERunnerConfigValidator.validate(config)
        }
    }

    @Test
    func rejectsInvalidPeerCoordinatorHost() throws {
        var config = makeConfig()
        config.peers[0].coordinatorHost = "ws://127.0.0.1:8123/e2e/session"

        #expect(throws: E2ERunnerError.invalidConfig("Peer alpha coordinatorHost must be a host name or IP address.")) {
            try E2ERunnerConfigValidator.validate(config)
        }
    }

    @Test
    func rejectsDuplicatePeerNames() throws {
        var config = makeConfig()
        config.peers[1].name = "alpha"

        #expect(throws: E2ERunnerError.invalidConfig("Duplicate peer name 'alpha'.")) {
            try E2ERunnerConfigValidator.validate(config)
        }
    }

    @Test
    func rejectsMissingXCTestDestination() throws {
        var config = makeConfig()
        config.peers[0].xctest?.destination = E2ERunnerConfig.Destination(
            raw: nil,
            platform: nil,
            id: nil,
            name: nil,
            os: nil
        )

        #expect(throws: E2ERunnerError.invalidConfig("Peer alpha xctest destination must define raw, id, or name.")) {
            try E2ERunnerConfigValidator.validate(config)
        }
    }

    @Test
    func buildsXcodebuildCommandAndInjectedEnvironment() throws {
        let plan = try E2ERunnerPlanBuilder(configDirectory: "/tmp/consumer-project").build(
            config: makeConfig(),
            sessionID: "session-1",
            resolvedPort: 8123,
            developerDirOverride: "/Xcode"
        )

        #expect(plan.sessionID == "session-1")
        #expect(plan.coordinatorURL == "ws://127.0.0.1:8123/e2e/session")
        #expect(plan.peers.count == 2)

        let alpha = try #require(plan.peers.first)
        #expect(alpha.name == "alpha")
        #expect(alpha.command.executable == "/usr/bin/xcrun")
        #expect(alpha.command.arguments.contains("xcodebuild"))
        #expect(alpha.command.arguments.contains("-workspace"))
        #expect(alpha.command.arguments.contains("/tmp/consumer-project/App.xcworkspace"))
        #expect(alpha.command.arguments.contains("-only-testing"))
        #expect(alpha.command.arguments.contains("ProductUITests/AlphaTests/testScenario"))
        #expect(alpha.command.arguments.last == "test-without-building")
        #expect(alpha.command.environment["DEVELOPER_DIR"] == "/Xcode")
        #expect(alpha.command.environment["E2E_SESSION_ID"] == "session-1")
        #expect(alpha.command.environment["E2E_PEER_NAME"] == "alpha")
        #expect(alpha.command.environment["E2E_COORDINATOR_URL"] == "ws://127.0.0.1:8123/e2e/session")
        #expect(alpha.command.environment["APP_E2E_MODE"] == "1")
    }

    @Test
    func buildsPeerSpecificCoordinatorURLWhenCoordinatorHostIsSet() throws {
        var config = makeConfig()
        config.peers[0].coordinatorHost = "169.254.14.34"
        config.peers[1].coordinatorHost = "169.254.228.136"

        let plan = try E2ERunnerPlanBuilder(configDirectory: "/tmp/consumer-project").build(
            config: config,
            sessionID: "session-1",
            resolvedPort: 8123
        )

        #expect(plan.coordinatorURL == "ws://127.0.0.1:8123/e2e/session")
        #expect(plan.peers[0].command.environment["E2E_COORDINATOR_URL"] == "ws://169.254.14.34:8123/e2e/session")
        #expect(plan.peers[1].command.environment["E2E_COORDINATOR_URL"] == "ws://169.254.228.136:8123/e2e/session")
    }

    @Test
    func buildsPeerListenerConnectionPlanAndEnvironment() throws {
        let config = try E2ERunnerConfigLoader.decode(text: peerListenerYaml(), format: .yaml)

        let plan = try E2ERunnerPlanBuilder(configDirectory: "/tmp/consumer-project").build(
            config: config,
            sessionID: "session-1"
        )

        #expect(plan.coordinatorURL == "peer-listener://harness")
        #expect(plan.peers[0].connection?.listenPort == 19131)
        #expect(plan.peers[0].connection?.connectHost == "127.0.0.1")
        #expect(plan.peers[0].connection?.connectPort == 18131)
        #expect(plan.peers[0].connection?.proxy?.kind == "iproxy")
        #expect(plan.peers[0].connection?.proxy?.udid == "00000000-0000000000000000")
        #expect(plan.peers[0].command.environment["E2E_TRANSPORT"] == "peer-listener")
        #expect(plan.peers[0].command.environment["E2E_PEER_LISTEN_PORT"] == "19131")
        #expect(plan.peers[0].command.environment["E2E_COORDINATOR_URL"] == "tcp-listener://127.0.0.1:19131/e2e/session")
    }

    @Test
    func rejectsPeerListenerWithoutConnection() throws {
        var config = try E2ERunnerConfigLoader.decode(text: peerListenerYaml(), format: .yaml)
        config.peers[0].connection = nil

        #expect(throws: E2ERunnerError.invalidConfig("Peer alpha requires connection config for peer-listener transport.")) {
            try E2ERunnerConfigValidator.validate(config)
        }
    }

    @Test
    func buildsProcessPeerCommand() throws {
        let plan = try E2ERunnerPlanBuilder(configDirectory: "/tmp/consumer-project").build(
            config: makeConfig(),
            sessionID: "session-1",
            resolvedPort: 8123
        )

        let beta = try #require(plan.peers.last)
        #expect(beta.kind == "process")
        #expect(beta.command.executable == "/tmp/consumer-project/.build/debug/e2e-fake-peer")
        #expect(beta.command.arguments == ["--peer", "beta"])
        #expect(beta.command.currentDirectory == "/tmp/consumer-project")
        #expect(beta.command.environment["E2E_PEER_NAME"] == "beta")
    }

    @Test
    func processSupervisorPropagatesFailure() async throws {
        let command = E2ECommand(
            executable: "/bin/false",
            arguments: [],
            environment: [:],
            currentDirectory: nil
        )
        let plan = E2ELaunchPlan(
            sessionID: "session-1",
            profileName: "profile",
            coordinatorURL: "ws://127.0.0.1:8123/e2e/session",
            artifactRoot: "/tmp/run",
            peers: [
                E2EPeerLaunchPlan(
                    name: "alpha",
                    role: nil,
                    kind: "process",
                    startCondition: "immediate",
                    artifactsDirectory: "/tmp/run/peers/alpha",
                    connection: nil,
                    command: command
                )
            ]
        )
        let supervisor = E2EPeerProcessSupervisor(processRunner: FakeProcessRunner(results: [
            E2EProcessResult(status: 42, output: "", error: "failed")
        ]))

        do {
            _ = try await supervisor.run(plan)
            Issue.record("Expected process failure")
        } catch let error as E2ERunnerError {
            #expect(error == .commandFailed(peerName: "alpha", status: 42))
        }
    }

    @Test
    func artifactWriterCreatesDeterministicLayout() throws {
        let root = temporaryDirectory("artifact-layout")
        let peerRoot = root.appendingPathComponent("peers/alpha").path
        let plan = E2ELaunchPlan(
            sessionID: "session-1",
            profileName: "profile",
            coordinatorURL: "ws://127.0.0.1:8123/e2e/session",
            artifactRoot: root.path,
            peers: [
                E2EPeerLaunchPlan(
                    name: "alpha",
                    role: "primary",
                    kind: "xctest",
                    startCondition: "immediate",
                    artifactsDirectory: peerRoot,
                    connection: nil,
                    command: E2ECommand(
                        executable: "/usr/bin/xcrun",
                        arguments: ["xcodebuild", "test-without-building"],
                        environment: ["E2E_PEER_NAME": "alpha"],
                        currentDirectory: "/tmp"
                    )
                )
            ]
        )
        let writer = E2ERunnerArtifactWriter()
        try writer.prepare(plan: plan)
        try writer.writePeerResult(
            E2EPeerExecutionResult(
                peerName: "alpha",
                result: E2EProcessResult(status: 13, output: "stdout-line", error: "stderr-line")
            ),
            plan: plan
        )
        try writer.writeSummary(
            plan: plan,
            results: [
                E2EPeerExecutionResult(
                    peerName: "alpha",
                    result: E2EProcessResult(status: 13, output: "stdout-line", error: "stderr-line")
                )
            ],
            status: "failed"
        )

        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("resolved-config.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("event-log.jsonl").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("receipts.jsonl").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("coordinator.log").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("session-summary.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("peers/alpha/launch.json").path))

        let log = try String(contentsOf: root.appendingPathComponent("peers/alpha/xcodebuild.log"), encoding: .utf8)
        #expect(log.contains("status: 13"))
        #expect(log.contains("stdout-line"))
        #expect(log.contains("stderr-line"))

        let summaryData = try Data(contentsOf: root.appendingPathComponent("session-summary.json"))
        let summary = try #require(JSONSerialization.jsonObject(with: summaryData) as? [String: Any])
        #expect(summary["status"] as? String == "failed")
        let peers = try #require(summary["peers"] as? [[String: Any]])
        #expect(peers.first?["logPath"] as? String == root.appendingPathComponent("peers/alpha/xcodebuild.log").path)
    }

    @Test
    func runtimeWritesFailureArtifactsBeforeThrowing() async throws {
        let root = temporaryDirectory("runtime-failure")
        let configPath = root.appendingPathComponent("e2e.yaml")
        try processOnlyYaml(artifactRoot: root.appendingPathComponent("run-${sessionId}").path)
            .write(to: configPath, atomically: true, encoding: .utf8)

        let runtime = E2ERunnerRuntime(processRunner: FakeProcessRunner(results: [
            E2EProcessResult(status: 7, output: "peer output", error: "peer error")
        ]))

        do {
            _ = try await runtime.run(options: E2ERunnerCLIOptions(
                configPath: configPath.path,
                dryRun: false,
                sessionID: "session-1"
            ))
            Issue.record("Expected runtime failure")
        } catch let error as E2ERunnerError {
            #expect(error == .commandFailed(peerName: "alpha", status: 7))
        }

        let runRoot = root.appendingPathComponent("run-session-1")
        let log = try String(contentsOf: runRoot.appendingPathComponent("peers/alpha/process.log"), encoding: .utf8)
        #expect(log.contains("peer output"))
        #expect(log.contains("peer error"))

        let summaryData = try Data(contentsOf: runRoot.appendingPathComponent("session-summary.json"))
        let summary = try #require(JSONSerialization.jsonObject(with: summaryData) as? [String: Any])
        #expect(summary["status"] as? String == "failed")
    }

    @Test
    func dryRunRendererIncludesPeerCommands() throws {
        let plan = try E2ERunnerPlanBuilder(configDirectory: "/tmp/consumer-project").build(
            config: makeConfig(),
            sessionID: "session-1",
            resolvedPort: 8123
        )

        let output = E2ELaunchPlanRenderer.renderDryRun(plan)

        #expect(output.contains("iOS E2E runner dry run"))
        #expect(output.contains("Coordinator: ws://127.0.0.1:8123/e2e/session"))
        #expect(output.contains("- alpha [xctest] start=immediate"))
        #expect(output.contains("- beta [process] start=event:alpha:alpha.ready"))
    }

    @Test
    func standaloneDryRunFixtureBuildsPlan() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configPath = repoRoot
            .appendingPathComponent("Samples/IOSE2ECoordinator/dry-run-two-peer.yaml")
            .path
        let config = try E2ERunnerConfigLoader.load(path: configPath)
        let configDirectory = URL(fileURLWithPath: configPath)
            .deletingLastPathComponent()
            .path
        let plan = try E2ERunnerPlanBuilder(configDirectory: configDirectory).build(
            config: config,
            sessionID: "fixture-session",
            resolvedPort: 8123
        )

        #expect(plan.profileName == "dry-run-two-peer")
        #expect(plan.peers.map(\.name) == ["alpha", "beta"])
        #expect(E2ELaunchPlanRenderer.renderDryRun(plan).contains("Session: fixture-session"))
    }
}

private func peerListenerYaml() -> String {
    """
    schemaVersion: 1
    profileName: local-peer-listener

    session:
      name: multi-peer-ui-e2e
      idPrefix: e2e

    coordinator:
      bindHost: 127.0.0.1
      advertisedHost: 127.0.0.1
      port: 0
      path: /e2e/session
      transport: peer-listener

    artifacts:
      root: .temp/e2e-runs/${sessionId}

    peers:
      - name: alpha
        role: primary
        connection:
          listenPort: 19131
          connectHost: 127.0.0.1
          connectPort: 18131
          proxy:
            kind: iproxy
        launch:
          kind: xctest
          startWhen:
            type: immediate
        xctest:
          workspace: App.xcworkspace
          scheme: ProductUITests
          destination:
            platform: iOS
            id: 00000000-0000000000000000
    """
}

private final class FakeProcessRunner: E2EProcessRunning, @unchecked Sendable {
    private let state: FakeProcessRunnerState

    init(results: [E2EProcessResult]) {
        self.state = FakeProcessRunnerState(results: results)
    }

    func run(_ command: E2ECommand) async throws -> E2EProcessResult {
        await state.next()
    }
}

private actor FakeProcessRunnerState {
    private var results: [E2EProcessResult]

    init(results: [E2EProcessResult]) {
        self.results = results
    }

    func next() -> E2EProcessResult {
        guard results.isEmpty == false else {
            return E2EProcessResult(status: 0, output: "", error: "")
        }

        return results.removeFirst()
    }
}

private func makeConfig() -> E2ERunnerConfig {
    try! E2ERunnerConfigLoader.decode(text: yamlConfig(), format: .yaml)
}

private func temporaryDirectory(_ name: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ios-e2e-runner-tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func yamlConfig() -> String {
    """
    schemaVersion: 1
    profileName: local-two-peer

    session:
      name: multi-peer-ui-e2e
      idPrefix: e2e

    coordinator:
      bindHost: 127.0.0.1
      advertisedHost: 127.0.0.1
      port: 0
      path: /e2e/session
      transport: websocket

    artifacts:
      root: .temp/e2e-runs/${sessionId}

    defaults:
      xcodebuild:
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
          scheme: ProductUITests
          destination:
            platform: iOS
            id: 00000000-0000000000000000
          onlyTesting:
            - ProductUITests/AlphaTests/testScenario
        appEnvironment:
          APP_E2E_MODE: "1"

      - name: beta
        role: secondary
        launch:
          kind: process
          startWhen:
            type: event
            event:
              name: alpha.ready
              fromPeer: alpha
              timeout: 30s
        process:
          executable: .build/debug/e2e-fake-peer
          arguments:
            - --peer
            - beta
          workingDirectory: .
    """
}

private func processOnlyYaml(artifactRoot: String) -> String {
    """
    schemaVersion: 1
    profileName: process-only

    session:
      name: process-only
      idPrefix: e2e

    coordinator:
      bindHost: 127.0.0.1
      advertisedHost: 127.0.0.1
      port: 0
      path: /e2e/session
      transport: websocket

    artifacts:
      root: \(artifactRoot)

    peers:
      - name: alpha
        role: primary
        launch:
          kind: process
          startWhen:
            type: immediate
        process:
          executable: /bin/echo
          arguments:
            - alpha
    """
}
