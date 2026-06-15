import Foundation
import IOSE2ECoordinatorCore
import IOSE2ECoordinatorTransport
import Yams

public enum E2ERunnerError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidArguments(String)
    case invalidConfig(String)
    case unsupportedSchemaVersion(Int)
    case commandFailed(peerName: String, status: Int32)

    public var description: String {
        switch self {
        case let .invalidArguments(message):
            return message
        case let .invalidConfig(message):
            return message
        case let .unsupportedSchemaVersion(version):
            return "Unsupported schemaVersion \(version)."
        case let .commandFailed(peerName, status):
            return "Peer \(peerName) failed with exit status \(status)."
        }
    }
}

public struct E2ERunnerCLIOptions: Equatable, Sendable {
    public var configPath: String?
    public var dryRun: Bool
    public var sessionID: String?
    public var developerDir: String?
    public var help: Bool

    public init(
        configPath: String? = nil,
        dryRun: Bool = false,
        sessionID: String? = nil,
        developerDir: String? = nil,
        help: Bool = false
    ) {
        self.configPath = configPath
        self.dryRun = dryRun
        self.sessionID = sessionID
        self.developerDir = developerDir
        self.help = help
    }

    public static func parse(_ arguments: [String]) throws -> E2ERunnerCLIOptions {
        var options = E2ERunnerCLIOptions()
        var index = 1

        func requireValue(for flag: String) throws -> String {
            guard index + 1 < arguments.count else {
                throw E2ERunnerError.invalidArguments("Missing value for \(flag).")
            }
            index += 1
            return arguments[index]
        }

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--config":
                options.configPath = try requireValue(for: argument)
            case "--dry-run":
                options.dryRun = true
            case "--session-id":
                options.sessionID = try requireValue(for: argument)
            case "--developer-dir":
                options.developerDir = try requireValue(for: argument)
            case "--help", "-h":
                options.help = true
            default:
                throw E2ERunnerError.invalidArguments("Unknown argument: \(argument).")
            }

            index += 1
        }

        if options.help {
            return options
        }

        guard options.configPath != nil else {
            throw E2ERunnerError.invalidArguments("Pass --config <path>.")
        }

        return options
    }
}

public struct E2ERunnerConfig: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var profileName: String
    public var session: Session
    public var coordinator: Coordinator
    public var artifacts: Artifacts
    public var defaults: Defaults?
    public var peers: [Peer]

    public struct Session: Codable, Equatable, Sendable {
        public var name: String
        public var idPrefix: String?
        public var metadata: [String: String]?
    }

    public struct Coordinator: Codable, Equatable, Sendable {
        public var bindHost: String
        public var advertisedHost: String
        public var port: Int
        public var path: String?
        public var transport: String
    }

    public struct Artifacts: Codable, Equatable, Sendable {
        public var root: String
        public var keepSuccessfulRuns: Bool?
        public var writeResolvedConfig: Bool?
        public var writeEventLog: Bool?
        public var writeReceipts: Bool?
        public var collectXcresults: Bool?
        public var collectScreenshots: Bool?
    }

    public struct Defaults: Codable, Equatable, Sendable {
        public var timeout: String?
        public var heartbeatInterval: String?
        public var reconnectWindow: String?
        public var payloadFormat: String?
        public var delivery: Delivery?
        public var xcodebuild: Xcodebuild?

        public struct Delivery: Codable, Equatable, Sendable {
            public var publishRequirement: String?
            public var ackTimeout: String?
            public var broadcast: String?
        }

        public struct Xcodebuild: Codable, Equatable, Sendable {
            public var developerDir: String?
            public var derivedDataRoot: String?
            public var configuration: String?
            public var sdk: String?
        }
    }

    public struct Peer: Codable, Equatable, Sendable {
        public var name: String
        public var role: String?
        public var metadata: [String: String]?
        public var coordinatorHost: String?
        public var connection: PeerConnection?
        public var launch: Launch
        public var xctest: XCTest?
        public var process: LocalProcess?
        public var appEnvironment: [String: String]?
        public var delivery: Defaults.Delivery?
        public var artifacts: Artifacts?
    }

    public struct PeerConnection: Codable, Equatable, Sendable {
        public var listenPort: Int
        public var connectHost: String?
        public var connectPort: Int
        public var proxy: Proxy?

        public struct Proxy: Codable, Equatable, Sendable {
            public var kind: String
            public var udid: String?
            public var executable: String?
        }
    }

    public struct Launch: Codable, Equatable, Sendable {
        public var kind: String
        public var startWhen: StartWhen
    }

    public struct StartWhen: Codable, Equatable, Sendable {
        public var type: String
        public var event: Event?

        public struct Event: Codable, Equatable, Sendable {
            public var name: String
            public var fromPeer: String?
            public var timeout: String?
        }
    }

    public struct XCTest: Codable, Equatable, Sendable {
        public var workspace: String?
        public var project: String?
        public var scheme: String
        public var testPlan: String?
        public var destination: Destination
        public var onlyTesting: [String]?
        public var skipTesting: [String]?
        public var xctestrun: String?
        public var buildForTesting: Bool?
    }

    public struct Destination: Codable, Equatable, Sendable {
        public var raw: String?
        public var platform: String?
        public var id: String?
        public var name: String?
        public var os: String?
    }

    public struct LocalProcess: Codable, Equatable, Sendable {
        public var executable: String
        public var arguments: [String]?
        public var workingDirectory: String?
    }
}

public enum E2ERunnerConfigLoader {
    public enum Format: Sendable {
        case yaml
        case json
    }

    public static func load(path: String) throws -> E2ERunnerConfig {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let format: Format = ext == "json" ? .json : .yaml
        return try decode(text: text, format: format)
    }

    public static func decode(text: String, format: Format) throws -> E2ERunnerConfig {
        switch format {
        case .json:
            return try JSONDecoder().decode(E2ERunnerConfig.self, from: Data(text.utf8))
        case .yaml:
            return try YAMLDecoder().decode(E2ERunnerConfig.self, from: text)
        }
    }
}

public enum E2ERunnerConfigValidator {
    public static func validate(_ config: E2ERunnerConfig) throws {
        guard config.schemaVersion == 1 else {
            throw E2ERunnerError.unsupportedSchemaVersion(config.schemaVersion)
        }

        guard ["websocket", "peer-listener"].contains(config.coordinator.transport) else {
            throw E2ERunnerError.invalidConfig("Coordinator transport must be websocket or peer-listener.")
        }

        guard config.coordinator.port >= 0 && config.coordinator.port <= 65_535 else {
            throw E2ERunnerError.invalidConfig("Coordinator port must be between 0 and 65535.")
        }

        guard config.peers.isEmpty == false else {
            throw E2ERunnerError.invalidConfig("Config must define at least one peer.")
        }

        var peerNames = Set<String>()
        for peer in config.peers {
            guard isValidPeerName(peer.name) else {
                throw E2ERunnerError.invalidConfig("Invalid peer name '\(peer.name)'.")
            }

            guard peerNames.insert(peer.name).inserted else {
                throw E2ERunnerError.invalidConfig("Duplicate peer name '\(peer.name)'.")
            }

            if let appEnvironment = peer.appEnvironment {
                for key in appEnvironment.keys where key.hasPrefix("E2E_") {
                    throw E2ERunnerError.invalidConfig("Peer \(peer.name) appEnvironment must not define reserved key \(key).")
                }
            }

            if let coordinatorHost = peer.coordinatorHost {
                let trimmed = coordinatorHost.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false, trimmed.contains("://") == false else {
                    throw E2ERunnerError.invalidConfig("Peer \(peer.name) coordinatorHost must be a host name or IP address.")
                }
            }

            switch peer.launch.kind {
            case "xctest":
                try validateXCTest(peer)
            case "process":
                guard peer.process != nil else {
                    throw E2ERunnerError.invalidConfig("Peer \(peer.name) launch.kind=process requires process config.")
                }
            default:
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) has unsupported launch kind '\(peer.launch.kind)'.")
            }

            if config.coordinator.transport == "peer-listener" {
                try validatePeerConnection(peer)
            }
        }

        for peer in config.peers {
            if peer.launch.startWhen.type == "event",
               let fromPeer = peer.launch.startWhen.event?.fromPeer,
               peerNames.contains(fromPeer) == false {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) waits for unknown peer \(fromPeer).")
            }
        }
    }

    private static func validateXCTest(_ peer: E2ERunnerConfig.Peer) throws {
        guard let xctest = peer.xctest else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) launch.kind=xctest requires xctest config.")
        }

        let hasWorkspace = xctest.workspace != nil
        let hasProject = xctest.project != nil
        guard hasWorkspace != hasProject else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) xctest config must define exactly one of workspace or project.")
        }

        guard xctest.destination.raw != nil
            || xctest.destination.id != nil
            || xctest.destination.name != nil else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) xctest destination must define raw, id, or name.")
        }
    }

    private static func validatePeerConnection(_ peer: E2ERunnerConfig.Peer) throws {
        guard let connection = peer.connection else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) requires connection config for peer-listener transport.")
        }

        guard (1...65_535).contains(connection.listenPort) else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) connection.listenPort must be between 1 and 65535.")
        }

        guard (1...65_535).contains(connection.connectPort) else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) connection.connectPort must be between 1 and 65535.")
        }

        guard connection.connectHost?.contains("://") != true else {
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) connection.connectHost must be a host name or IP address.")
        }

        if let proxy = connection.proxy {
            guard proxy.kind == "iproxy" else {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) connection.proxy.kind must be iproxy.")
            }

            let udid = proxy.udid ?? peer.xctest?.destination.id
            guard let udid, udid.isEmpty == false else {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) connection.proxy.kind=iproxy requires proxy.udid or xctest.destination.id.")
            }
        }
    }

    private static func isValidPeerName(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first,
              CharacterSet.letters.contains(first),
              value.count <= 64 else {
            return false
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

public struct E2ELaunchPlan: Codable, Equatable, Sendable {
    public var sessionID: String
    public var profileName: String
    public var coordinatorURL: String
    public var artifactRoot: String
    public var peers: [E2EPeerLaunchPlan]
}

public struct E2EPeerLaunchPlan: Codable, Equatable, Sendable {
    public var name: String
    public var role: String?
    public var kind: String
    public var startCondition: String
    public var artifactsDirectory: String
    public var connection: E2EPeerConnectionPlan? = nil
    public var command: E2ECommand
}

public struct E2EPeerConnectionPlan: Codable, Equatable, Sendable {
    public var listenPort: Int
    public var connectHost: String
    public var connectPort: Int
    public var proxy: Proxy?

    public struct Proxy: Codable, Equatable, Sendable {
        public var kind: String
        public var udid: String
        public var executable: String
        public var logPath: String
    }
}

public struct E2ECommand: Codable, Equatable, Sendable {
    public var executable: String
    public var arguments: [String]
    public var environment: [String: String]
    public var currentDirectory: String?
}

public struct E2ERunnerPlanBuilder: Sendable {
    private let configDirectory: String

    public init(configDirectory: String) {
        self.configDirectory = configDirectory
    }

    public func build(
        config: E2ERunnerConfig,
        sessionID requestedSessionID: String? = nil,
        resolvedPort: Int? = nil,
        developerDirOverride: String? = nil
    ) throws -> E2ELaunchPlan {
        try E2ERunnerConfigValidator.validate(config)

        let sessionID = requestedSessionID ?? generatedSessionID(prefix: config.session.idPrefix ?? "e2e")
        let port = resolvedPort ?? config.coordinator.port
        let path = config.coordinator.path ?? "/e2e/session"
        let host = resolvedAdvertisedHost(config.coordinator.advertisedHost)
        let coordinatorURL = coordinatorURL(config: config, host: host, port: port, path: path)
        let artifactRoot = resolvePath(render(config.artifacts.root, sessionID: sessionID, profileName: config.profileName))

        let peers = try config.peers.map { peer in
            let artifactsDirectory = URL(fileURLWithPath: artifactRoot)
                .appendingPathComponent("peers")
                .appendingPathComponent(peer.name)
                .standardized
                .path
            let peerHost = resolvedAdvertisedHost(peer.coordinatorHost ?? config.coordinator.advertisedHost)
            let peerConnection = try connectionPlan(for: peer, artifactsDirectory: artifactsDirectory)
            let peerCoordinatorURL = peerURL(
                config: config,
                peerHost: peerHost,
                port: port,
                path: path,
                connection: peerConnection
            )
            let environment = peerEnvironment(
                config: config,
                peer: peer,
                sessionID: sessionID,
                coordinatorURL: peerCoordinatorURL,
                connection: peerConnection,
                artifactsDirectory: artifactsDirectory,
                developerDirOverride: developerDirOverride
            )
            let command = try commandForPeer(
                config: config,
                peer: peer,
                sessionID: sessionID,
                artifactsDirectory: artifactsDirectory,
                environment: environment,
                developerDirOverride: developerDirOverride
            )
            return E2EPeerLaunchPlan(
                name: peer.name,
                role: peer.role,
                kind: peer.launch.kind,
                startCondition: startCondition(peer.launch.startWhen),
                artifactsDirectory: artifactsDirectory,
                connection: peerConnection,
                command: command
            )
        }

        return E2ELaunchPlan(
            sessionID: sessionID,
            profileName: config.profileName,
            coordinatorURL: coordinatorURL,
            artifactRoot: artifactRoot,
            peers: peers
        )
    }

    private func peerEnvironment(
        config: E2ERunnerConfig,
        peer: E2ERunnerConfig.Peer,
        sessionID: String,
        coordinatorURL: String,
        connection: E2EPeerConnectionPlan?,
        artifactsDirectory: String,
        developerDirOverride: String?
    ) -> [String: String] {
        var environment = peer.appEnvironment ?? [:]
        environment["E2E_SESSION_ID"] = sessionID
        environment["E2E_PROFILE_NAME"] = config.profileName
        environment["E2E_PEER_NAME"] = peer.name
        environment["E2E_COORDINATOR_URL"] = coordinatorURL
        environment["E2E_TRANSPORT"] = config.coordinator.transport
        environment["E2E_ARTIFACTS_DIR"] = artifactsDirectory
        environment["E2E_LAST_SEEN_SEQ"] = "0"

        if let connection {
            environment["E2E_PEER_LISTEN_PORT"] = "\(connection.listenPort)"
        }

        if let role = peer.role {
            environment["E2E_PEER_ROLE"] = role
        }

        if let developerDir = developerDirOverride ?? config.defaults?.xcodebuild?.developerDir {
            environment["DEVELOPER_DIR"] = developerDir
        }

        return environment
    }

    private func commandForPeer(
        config: E2ERunnerConfig,
        peer: E2ERunnerConfig.Peer,
        sessionID: String,
        artifactsDirectory: String,
        environment: [String: String],
        developerDirOverride: String?
    ) throws -> E2ECommand {
        switch peer.launch.kind {
        case "xctest":
            guard let xctest = peer.xctest else {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) launch.kind=xctest requires xctest config.")
            }
            return xcodebuildCommand(
                config: config,
                peer: peer,
                xctest: xctest,
                sessionID: sessionID,
                artifactsDirectory: artifactsDirectory,
                environment: environment
            )
        case "process":
            guard let process = peer.process else {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) launch.kind=process requires process config.")
            }
            return E2ECommand(
                executable: resolvePath(process.executable),
                arguments: process.arguments ?? [],
                environment: environment,
                currentDirectory: resolvePath(process.workingDirectory ?? ".")
            )
        default:
            throw E2ERunnerError.invalidConfig("Peer \(peer.name) has unsupported launch kind '\(peer.launch.kind)'.")
        }
    }

    private func xcodebuildCommand(
        config: E2ERunnerConfig,
        peer: E2ERunnerConfig.Peer,
        xctest: E2ERunnerConfig.XCTest,
        sessionID: String,
        artifactsDirectory: String,
        environment: [String: String]
    ) -> E2ECommand {
        var arguments = ["xcodebuild"]

        if let xctestrun = xctest.xctestrun {
            arguments += ["-xctestrun", resolvePath(render(xctestrun, sessionID: sessionID, profileName: config.profileName))]
        } else {
            if let workspace = xctest.workspace {
                arguments += ["-workspace", resolvePath(workspace)]
            }
            if let project = xctest.project {
                arguments += ["-project", resolvePath(project)]
            }
            arguments += ["-scheme", xctest.scheme]
        }

        if let configuration = config.defaults?.xcodebuild?.configuration {
            arguments += ["-configuration", configuration]
        }
        if let sdk = config.defaults?.xcodebuild?.sdk {
            arguments += ["-sdk", sdk]
        }
        if let testPlan = xctest.testPlan {
            arguments += ["-testPlan", testPlan]
        }

        arguments += ["-destination", destinationString(xctest.destination)]

        let derivedDataRoot = config.defaults?.xcodebuild?.derivedDataRoot
            ?? ".temp/e2e-derived-data/${sessionId}"
        let derivedDataPath = URL(fileURLWithPath: resolvePath(render(
            derivedDataRoot,
            sessionID: sessionID,
            profileName: config.profileName
        )))
        .appendingPathComponent(peer.name)
        .standardized
        .path

        arguments += ["-derivedDataPath", derivedDataPath]
        arguments += ["-resultBundlePath", URL(fileURLWithPath: artifactsDirectory)
            .appendingPathComponent("result.xcresult")
            .standardized
            .path]

        for selector in xctest.onlyTesting ?? [] {
            arguments += ["-only-testing", selector]
        }
        for selector in xctest.skipTesting ?? [] {
            arguments += ["-skip-testing", selector]
        }

        arguments.append(xctest.buildForTesting == true ? "test" : "test-without-building")

        return E2ECommand(
            executable: "/usr/bin/xcrun",
            arguments: arguments,
            environment: environment,
            currentDirectory: configDirectory
        )
    }

    private func destinationString(_ destination: E2ERunnerConfig.Destination) -> String {
        if let raw = destination.raw {
            return raw
        }

        var parts = ["platform=\(destination.platform ?? "iOS")"]
        if let id = destination.id {
            parts.append("id=\(id)")
        }
        if let name = destination.name {
            parts.append("name=\(name)")
        }
        if let os = destination.os {
            parts.append("OS=\(os)")
        }
        return parts.joined(separator: ",")
    }

    private func startCondition(_ startWhen: E2ERunnerConfig.StartWhen) -> String {
        switch startWhen.type {
        case "event":
            let eventName = startWhen.event?.name ?? "unknown"
            if let fromPeer = startWhen.event?.fromPeer {
                return "event:\(fromPeer):\(eventName)"
            }
            return "event:\(eventName)"
        default:
            return startWhen.type
        }
    }

    private func render(_ value: String, sessionID: String, profileName: String) -> String {
        value
            .replacingOccurrences(of: "${sessionId}", with: sessionID)
            .replacingOccurrences(of: "${profileName}", with: profileName)
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardized.path
        }

        return URL(fileURLWithPath: configDirectory)
            .appendingPathComponent(path)
            .standardized
            .path
    }

    private func resolvedAdvertisedHost(_ host: String) -> String {
        host == "auto" ? "127.0.0.1" : host
    }

    private func websocketURL(host: String, port: Int, path: String) -> String {
        let renderedHost = host.contains(":") && host.hasPrefix("[") == false ? "[\(host)]" : host
        return "ws://\(renderedHost):\(port)\(path)"
    }

    private func coordinatorURL(config: E2ERunnerConfig, host: String, port: Int, path: String) -> String {
        switch config.coordinator.transport {
        case "peer-listener":
            return "peer-listener://harness"
        default:
            return websocketURL(host: host, port: port, path: path)
        }
    }

    private func peerURL(
        config: E2ERunnerConfig,
        peerHost: String,
        port: Int,
        path: String,
        connection: E2EPeerConnectionPlan?
    ) -> String {
        switch config.coordinator.transport {
        case "peer-listener":
            let listenPort = connection?.listenPort ?? 0
            return "tcp-listener://127.0.0.1:\(listenPort)\(path)"
        default:
            return websocketURL(host: peerHost, port: port, path: path)
        }
    }

    private func connectionPlan(
        for peer: E2ERunnerConfig.Peer,
        artifactsDirectory: String
    ) throws -> E2EPeerConnectionPlan? {
        guard let connection = peer.connection else {
            return nil
        }

        let proxy: E2EPeerConnectionPlan.Proxy?
        if let configProxy = connection.proxy {
            let udid = configProxy.udid ?? peer.xctest?.destination.id
            guard let udid else {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) connection.proxy.kind=iproxy requires proxy.udid or xctest.destination.id.")
            }
            proxy = E2EPeerConnectionPlan.Proxy(
                kind: configProxy.kind,
                udid: udid,
                executable: executablePath(configProxy.executable ?? "iproxy"),
                logPath: URL(fileURLWithPath: artifactsDirectory)
                    .appendingPathComponent("iproxy.log")
                    .standardized
                    .path
            )
        } else {
            proxy = nil
        }

        return E2EPeerConnectionPlan(
            listenPort: connection.listenPort,
            connectHost: connection.connectHost ?? "127.0.0.1",
            connectPort: connection.connectPort,
            proxy: proxy
        )
    }

    private func executablePath(_ value: String) -> String {
        value.contains("/") ? resolvePath(value) : value
    }

    private func generatedSessionID(prefix: String) -> String {
        let suffix = UUID().uuidString.lowercased().prefix(8)
        return "\(prefix)-\(Int(Date().timeIntervalSince1970))-\(suffix)"
    }
}

public enum E2ELaunchPlanRenderer {
    public static func renderDryRun(_ plan: E2ELaunchPlan) -> String {
        var lines: [String] = [
            "iOS E2E runner dry run",
            "Session: \(plan.sessionID)",
            "Profile: \(plan.profileName)",
            "Coordinator: \(plan.coordinatorURL)",
            "Artifacts: \(plan.artifactRoot)",
            "Peers:"
        ]

        for peer in plan.peers {
            lines.append("- \(peer.name) [\(peer.kind)] start=\(peer.startCondition)")
            lines.append("  artifacts=\(peer.artifactsDirectory)")
            if let connection = peer.connection {
                lines.append("  connection=listen:\(connection.listenPort) connect:\(connection.connectHost):\(connection.connectPort)")
                if let proxy = connection.proxy {
                    lines.append("  proxy=\(proxy.kind) \(proxy.udid) \(connection.connectPort):\(connection.listenPort)")
                }
            }
            lines.append("  command=\(shellJoined([peer.command.executable] + peer.command.arguments))")
            if let currentDirectory = peer.command.currentDirectory {
                lines.append("  cwd=\(currentDirectory)")
            }
            lines.append("  environment:")
            for key in peer.command.environment.keys.sorted() {
                lines.append("    \(key)=\(peer.command.environment[key] ?? "")")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func shellJoined(_ values: [String]) -> String {
        values.map { value in
            guard value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else {
                return value
            }
            return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
        }
        .joined(separator: " ")
    }
}

public struct E2EProcessResult: Equatable, Sendable {
    public var status: Int32
    public var output: String
    public var error: String
}

public protocol E2EProcessRunning: Sendable {
    func run(_ command: E2ECommand) async throws -> E2EProcessResult
}

public final class E2ESystemProcessRunner: E2EProcessRunning, @unchecked Sendable {
    public init() {}

    public func run(_ command: E2ECommand) async throws -> E2EProcessResult {
        let managedProcess = E2EManagedProcess()
        let process = managedProcess.process
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments

        var environment = ProcessInfo.processInfo.environment
        command.environment.forEach { environment[$0.key] = $0.value }
        process.environment = environment

        if let currentDirectory = command.currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try await withTaskCancellationHandler {
            try process.run()
            process.waitUntilExit()
        } onCancel: {
            managedProcess.terminate()
        }

        return E2EProcessResult(
            status: process.terminationStatus,
            output: String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            error: String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}

private final class E2EManagedProcess: @unchecked Sendable {
    let process = Process()

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }
}

public struct E2EPeerExecutionResult: Equatable, Sendable {
    public var peerName: String
    public var result: E2EProcessResult
}

public struct E2EPeerProcessSupervisor<Runner: E2EProcessRunning>: Sendable {
    private let processRunner: Runner

    public init(processRunner: Runner) {
        self.processRunner = processRunner
    }

    public func run(_ plan: E2ELaunchPlan) async throws -> [E2EPeerExecutionResult] {
        let results = try await runCollecting(plan)
        if let failure = results.first(where: { $0.result.status != 0 }) {
            throw E2ERunnerError.commandFailed(peerName: failure.peerName, status: failure.result.status)
        }

        return results
    }

    public func runCollecting(_ plan: E2ELaunchPlan) async throws -> [E2EPeerExecutionResult] {
        let order = Dictionary(uniqueKeysWithValues: plan.peers.enumerated().map { ($0.element.name, $0.offset) })

        return try await withThrowingTaskGroup(of: E2EPeerExecutionResult.self) { group in
            for peer in plan.peers {
                group.addTask {
                    let result = try await processRunner.run(peer.command)
                    return E2EPeerExecutionResult(peerName: peer.name, result: result)
                }
            }

            var results: [E2EPeerExecutionResult] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted { lhs, rhs in
                (order[lhs.peerName] ?? Int.max) < (order[rhs.peerName] ?? Int.max)
            }
        }
    }
}

public final class E2EPeerListenerProxySupervisor: @unchecked Sendable {
    private var processes: [Process] = []

    public init() {}

    public func start(plan: E2ELaunchPlan) throws {
        for peer in plan.peers {
            guard let connection = peer.connection,
                  let proxy = connection.proxy else {
                continue
            }

            switch proxy.kind {
            case "iproxy":
                try startIproxy(peerName: peer.name, connection: connection, proxy: proxy)
            default:
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) has unsupported proxy kind \(proxy.kind).")
            }
        }
    }

    public func stop() {
        for process in processes {
            if process.isRunning {
                process.terminate()
            }
        }
        processes.removeAll()
    }

    private func startIproxy(
        peerName: String,
        connection: E2EPeerConnectionPlan,
        proxy: E2EPeerConnectionPlan.Proxy
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath(proxy.executable))
        process.arguments = [
            "--udid", proxy.udid,
            "\(connection.connectPort):\(connection.listenPort)"
        ]

        FileManager.default.createFile(atPath: proxy.logPath, contents: nil)
        let logHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: proxy.logPath))
        process.standardOutput = logHandle
        process.standardError = logHandle

        do {
            try process.run()
            processes.append(process)
        } catch {
            try? logHandle.close()
            throw E2ERunnerError.invalidConfig("Failed to start iproxy for peer \(peerName): \(error.localizedDescription)")
        }
    }

    private func executablePath(_ executable: String) -> String {
        if executable.contains("/") {
            return executable
        }

        let pathValues = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        for directory in pathValues {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(executable).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return executable
    }
}

public struct E2ERunnerRuntime<Runner: E2EProcessRunning>: Sendable {
    private let processRunner: Runner

    public init(processRunner: Runner) {
        self.processRunner = processRunner
    }

    public func run(options: E2ERunnerCLIOptions) async throws -> String {
        guard let configPath = options.configPath else {
            throw E2ERunnerError.invalidArguments("Pass --config <path>.")
        }

        let config = try E2ERunnerConfigLoader.load(path: configPath)
        let configDirectory = URL(fileURLWithPath: configPath)
            .deletingLastPathComponent()
            .standardized
            .path
        let builder = E2ERunnerPlanBuilder(configDirectory: configDirectory)

        if options.dryRun {
            let plan = try builder.build(
                config: config,
                sessionID: options.sessionID,
                developerDirOverride: options.developerDir
            )
            return E2ELaunchPlanRenderer.renderDryRun(plan)
        }

        let sessionID = options.sessionID ?? "e2e-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.lowercased().prefix(8))"
        let artifactWriter = E2ERunnerArtifactWriter()
        switch config.coordinator.transport {
        case "peer-listener":
            return try await runPeerListener(
                config: config,
                builder: builder,
                sessionID: sessionID,
                developerDir: options.developerDir,
                artifactWriter: artifactWriter
            )
        default:
            return try await runWebSocket(
                config: config,
                builder: builder,
                sessionID: sessionID,
                developerDir: options.developerDir,
                artifactWriter: artifactWriter
            )
        }
    }

    private func runWebSocket(
        config: E2ERunnerConfig,
        builder: E2ERunnerPlanBuilder,
        sessionID: String,
        developerDir: String?,
        artifactWriter: E2ERunnerArtifactWriter
    ) async throws -> String {
        let preflightPlan = try builder.build(
            config: config,
            sessionID: sessionID,
            resolvedPort: config.coordinator.port,
            developerDirOverride: developerDir
        )
        let recorder = E2ERunnerFileSessionRecorder(artifactRoot: preflightPlan.artifactRoot)
        let core = E2ESessionEventCore(sessionID: E2ESessionID(sessionID))
        let server = E2EWebSocketCoordinatorServer(
            configuration: E2EWebSocketCoordinatorServer.Configuration(
                bindHost: config.coordinator.bindHost,
                port: config.coordinator.port,
                path: config.coordinator.path ?? "/e2e/session"
            ),
            core: core,
            recorder: recorder
        )
        let port = try server.start()
        defer { try? server.stop() }

        let plan = try builder.build(
            config: config,
            sessionID: sessionID,
            resolvedPort: port,
            developerDirOverride: developerDir
        )
        return try await runPeers(plan: plan, artifactWriter: artifactWriter)
    }

    private func runPeerListener(
        config: E2ERunnerConfig,
        builder: E2ERunnerPlanBuilder,
        sessionID: String,
        developerDir: String?,
        artifactWriter: E2ERunnerArtifactWriter
    ) async throws -> String {
        let plan = try builder.build(
            config: config,
            sessionID: sessionID,
            resolvedPort: config.coordinator.port,
            developerDirOverride: developerDir
        )
        try artifactWriter.prepare(plan: plan)

        let recorder = E2ERunnerFileSessionRecorder(artifactRoot: plan.artifactRoot)
        let core = E2ESessionEventCore(sessionID: E2ESessionID(sessionID))
        let coordinator = E2ETCPPeerCoordinatorClient(core: core, recorder: recorder)
        let proxySupervisor = E2EPeerListenerProxySupervisor()
        try proxySupervisor.start(plan: plan)
        defer {
            coordinator.stop()
            proxySupervisor.stop()
        }

        let supervisor = E2EPeerProcessSupervisor(processRunner: processRunner)
        let peerTask = Task {
            try await supervisor.runCollecting(plan)
        }
        await Task.yield()

        do {
            try await coordinator.connectAll(plan.tcpEndpoints(), timeoutSeconds: 60)
            let results = try await peerTask.value
            return try finish(plan: plan, results: results, artifactWriter: artifactWriter)
        } catch {
            peerTask.cancel()
            let results = (try? await peerTask.value) ?? []
            for result in results {
                try? artifactWriter.writePeerResult(result, plan: plan)
            }
            try? artifactWriter.writeSummary(plan: plan, results: results, status: "failed")
            throw error
        }
    }

    private func runPeers(
        plan: E2ELaunchPlan,
        artifactWriter: E2ERunnerArtifactWriter
    ) async throws -> String {
        try artifactWriter.prepare(plan: plan)
        let supervisor = E2EPeerProcessSupervisor(processRunner: processRunner)
        let results: [E2EPeerExecutionResult]

        do {
            results = try await supervisor.runCollecting(plan)
        } catch {
            try? artifactWriter.writeSummary(plan: plan, results: [], status: "failed")
            throw error
        }

        return try finish(plan: plan, results: results, artifactWriter: artifactWriter)
    }

    private func finish(
        plan: E2ELaunchPlan,
        results: [E2EPeerExecutionResult],
        artifactWriter: E2ERunnerArtifactWriter
    ) throws -> String {
        for result in results {
            try artifactWriter.writePeerResult(result, plan: plan)
        }

        if let failure = results.first(where: { $0.result.status != 0 }) {
            try artifactWriter.writeSummary(plan: plan, results: results, status: "failed")
            throw E2ERunnerError.commandFailed(peerName: failure.peerName, status: failure.result.status)
        }

        try artifactWriter.writeSummary(plan: plan, results: results, status: "passed")

        return "Session \(plan.sessionID) completed.\nArtifacts: \(plan.artifactRoot)"
    }
}

private extension E2ELaunchPlan {
    func tcpEndpoints() throws -> [E2ETCPPeerEndpoint] {
        try peers.map { peer in
            guard let connection = peer.connection else {
                throw E2ERunnerError.invalidConfig("Peer \(peer.name) requires connection config for peer-listener transport.")
            }

            return E2ETCPPeerEndpoint(
                peerName: E2EPeerName(peer.name),
                host: connection.connectHost,
                port: connection.connectPort
            )
        }
    }
}

public func e2eRunnerUsage() -> String {
    """
    ios-e2e-runner - Coordinate multi-peer iOS UI E2E sessions.

    Usage:
      ios-e2e-runner --config path/to/e2e.yaml [--dry-run] [--session-id id] [--developer-dir path]

    Options:
      --config <path>        Required. YAML or JSON coordinator config.
      --dry-run              Validate config and print the peer launch plan without starting peers.
      --session-id <id>      Optional deterministic session id.
      --developer-dir <path> Optional DEVELOPER_DIR override injected into peer processes.
      --help                 Show this help.
    """
}
